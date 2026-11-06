defmodule Runeshare.Sharing.Preset do
  @moduledoc """
  A shareable plugin string. `kind` says which plugin it is for; `content` is the
  exact text users paste into the plugin's import box.
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshStorage]

  @kinds [:watchdog_alarm, :tile_marker]

  postgres do
    table "presets"
    repo Runeshare.Repo

    references do
      reference :author, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:kind, :inserted_at]
      index [:kind, :content_hash]
      index [:tags], using: "GIN"
    end
  end

  # Dev stores files on disk (served at /storage); test and prod override the
  # service in config (`AshStorage.Service.Test`, Tigris over S3).
  storage do
    service({AshStorage.Service.Disk, root: "priv/storage", base_url: "/storage"})
    blob_resource(Runeshare.Sharing.StorageBlob)
    attachment_resource(Runeshare.Sharing.StorageAttachment)

    # One optional image per preset; replacing or deleting the preset purges the file.
    has_one_attached(:cover_image, dependent: :purge)
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      description "Visible presets of one kind, sorted, optionally narrowed by title search and tag."

      argument :kind, :atom do
        allow_nil? false
        constraints one_of: @kinds
      end

      argument :search, :string

      argument :sort, :atom do
        default :newest
        constraints one_of: [:newest, :most_liked, :most_copied]
      end

      argument :tag, :string

      filter expr(kind == ^arg(:kind))

      filter expr(
               is_nil(^arg(:search)) or
                 contains(string_downcase(title), string_downcase(^arg(:search)))
             )

      filter expr(is_nil(^arg(:tag)) or fragment("? = ANY(?)", ^arg(:tag), tags))

      prepare build(load: [:author, :like_count, :comment_count, :copy_count, :cover_image_url])
      prepare Runeshare.Sharing.Preset.Preparations.SortByArgument

      pagination offset?: true, default_limit: 24, countable: true, required?: false
    end

    read :mine do
      description "Presets shared by the current user, newest first."
      filter expr(author_id == ^actor(:id))

      prepare build(
                sort: [inserted_at: :desc],
                load: [:like_count, :comment_count, :copy_count, :cover_image_url]
              )
    end

    read :liked do
      description "Presets the current user has liked, newest first."
      filter expr(exists(likes, user_id == ^actor(:id)))

      prepare build(
                sort: [inserted_at: :desc],
                load: [:author, :like_count, :comment_count, :copy_count, :cover_image_url]
              )
    end

    read :by_author do
      description "A user's visible presets, newest first, for their public profile."
      argument :author_id, :uuid, allow_nil?: false
      filter expr(author_id == ^arg(:author_id))

      prepare build(
                sort: [inserted_at: :desc],
                load: [:like_count, :comment_count, :copy_count, :cover_image_url]
              )
    end

    read :duplicates do
      description "Visible presets of `kind` whose import string is exactly `content`."
      argument :kind, :atom, allow_nil?: false, constraints: [one_of: @kinds]
      argument :content, :string, allow_nil?: false
      filter expr(kind == ^arg(:kind))
      prepare Runeshare.Sharing.Preset.Preparations.FilterByContentHash
    end

    create :share do
      accept [:kind, :title, :description, :content, :tags]

      argument :cover_image, Ash.Type.File do
        description "Optional JPEG, PNG or WebP image (≤ 2 MB), resized by the browser first."
      end

      validate Runeshare.Sharing.Preset.Validations.CoverImage

      validate {Runeshare.Sharing.Validations.RateLimit,
                max: 10, per_seconds: 3600, field: :author_id}

      change relate_actor(:author, allow_nil?: true)
      change Runeshare.Sharing.Preset.Changes.NormalizeTags
      change Runeshare.Sharing.Preset.Changes.HashContent
      change Runeshare.Sharing.Preset.Changes.SnapshotVersion

      change {AshStorage.Changes.HandleFileArgument,
              argument: :cover_image, attachment: :cover_image}
    end

    update :edit do
      description "Saves a new version (v2, v3, ...). Older versions stay readable."
      accept [:title, :description, :content, :tags]

      argument :change_note, :string do
        description "What changed in this version, shown in the versions list."
        constraints max_length: 200, trim?: true
      end

      argument :cover_image, Ash.Type.File do
        description "Replaces the cover image (the old file is purged)."
      end

      argument :remove_cover_image, :boolean do
        description "Removes the cover image. Ignored when a new one is given."
        default false
      end

      validate Runeshare.Sharing.Preset.Validations.CoverImage

      # The snapshot needs the final values and the next number, which an atomic
      # update cannot hand to manage_relationship. Two simultaneous edits of the
      # same preset collide on the (preset_id, number) unique index instead.
      require_atomic? false
      change Runeshare.Sharing.Preset.Changes.NormalizeTags
      change Runeshare.Sharing.Preset.Changes.HashContent
      change Runeshare.Sharing.Preset.Changes.SnapshotVersion

      change {AshStorage.Changes.HandleFileArgument,
              argument: :cover_image, attachment: :cover_image}

      change {AshStorage.Changes.Purge, attachment_name: :cover_image},
        where: [argument_equals(:remove_cover_image, true), argument_equals(:cover_image, nil)]
    end

    update :hide do
      description "Moderation: take a preset out of listings and public view."
      accept []
      change set_attribute(:hidden, true)
    end

    update :unhide do
      accept []
      change set_attribute(:hidden, false)
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Hidden presets are only visible to their author (and admins, above).
    policy action_type(:read) do
      authorize_if expr(hidden == false)
      authorize_if relates_to_actor_via(:author)
    end

    policy action([:mine, :liked]) do
      authorize_if actor_present()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action([:edit, :destroy]) do
      authorize_if relates_to_actor_via(:author)
    end

    policy action([:hide, :unhide]) do
      forbid_if always()
    end
  end

  # Topics: "presets:shared:<kind>", "presets:deleted:<kind>", "presets:<id>".
  pub_sub do
    module RuneshareWeb.Endpoint
    prefix "presets"
    publish :share, ["shared", :kind]
    publish :destroy, ["deleted", :kind]
    publish :hide, ["deleted", :kind]
    publish :unhide, ["shared", :kind]
    publish :edit, [:id]
    publish :hide, [:id]
    publish :unhide, [:id]
    publish :destroy, [:id]
  end

  validations do
    validate Runeshare.Sharing.Preset.Validations.ImportStringFormat, where: changing(:content)
  end

  attributes do
    uuid_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: @kinds
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 3, max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :content, :string do
      allow_nil? false
      public? true
      constraints max_length: 100_000, trim?: true
    end

    attribute :tags, {:array, :string} do
      description "Up to 5 lowercase tags (boss, skill, activity), e.g. `vorago`."
      allow_nil? false
      public? true
      default []
      constraints max_length: 5, items: [min_length: 2, max_length: 24, trim?: true]
    end

    attribute :content_hash, :string do
      description "SHA-256 of `content`, to spot identical shares."
      allow_nil? false
      public? true
      writable? false
    end

    attribute :hidden, :boolean do
      description "Hidden by a moderator."
      allow_nil? false
      public? true
      default false
      writable? false
    end

    attribute :version, :integer do
      description "Number of the current (newest) version."
      allow_nil? false
      public? true
      default 1
      writable? false
    end

    timestamps()
  end

  relationships do
    belongs_to :author, Runeshare.Accounts.User do
      allow_nil? false
      public? true
    end

    has_many :likes, Runeshare.Sharing.Like do
      public? true
    end

    has_many :comments, Runeshare.Sharing.Comment do
      public? true
    end

    has_many :versions, Runeshare.Sharing.PresetVersion do
      public? true
      sort number: :desc
    end

    has_many :reports, Runeshare.Sharing.Report do
      public? true
    end

    has_many :copies, Runeshare.Sharing.PresetCopy do
      public? true
    end
  end

  calculations do
    calculate :liked_by_me, :boolean, expr(exists(likes, user_id == ^actor(:id))) do
      public? true
    end
  end

  aggregates do
    count :like_count, :likes do
      public? true
    end

    count :comment_count, :comments do
      public? true
    end

    count :copy_count, :copies do
      description "Visitors who copied the import string (each counted once)."
      public? true
    end

    count :open_report_count, :reports do
      public? true
      filter expr(status == :open)
    end
  end

  @doc "Every supported preset kind."
  @spec kinds() :: list(atom())
  def kinds, do: @kinds
end
