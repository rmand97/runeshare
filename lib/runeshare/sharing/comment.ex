defmodule Runeshare.Sharing.Comment do
  @moduledoc """
  A comment on a preset. Removable by its author or by the preset's author.
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    simple_notifiers: [Runeshare.ActionLog.Notifier]

  postgres do
    table "comments"
    repo Runeshare.Repo

    references do
      reference :preset, on_delete: :delete
      reference :author, on_delete: :delete
    end

    custom_indexes do
      index [:preset_id, :inserted_at]
    end
  end

  actions do
    defaults [:read]

    read :for_preset do
      description "A preset's comments, oldest first, with their authors."
      argument :preset_id, :uuid, allow_nil?: false
      filter expr(preset_id == ^arg(:preset_id))
      prepare build(sort: [inserted_at: :asc], load: [:author])
    end

    create :post do
      accept [:preset_id, :body]

      validate {Runeshare.Sharing.Validations.RateLimit,
                max: 10, per_seconds: 300, field: :author_id}

      change relate_actor(:author, allow_nil?: true)
      change Runeshare.Sharing.Comment.Changes.StampPresetVersion
    end

    destroy :remove do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if action_type([:read, :destroy])
    end

    # A hidden preset's comments are as private as the preset itself.
    policy action_type(:read) do
      authorize_if expr(preset.hidden == false)
      authorize_if relates_to_actor_via([:preset, :author])
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:author)
      authorize_if relates_to_actor_via([:preset, :author])
    end
  end

  pub_sub do
    module RuneshareWeb.Endpoint
    prefix "comments"
    publish_all :create, [:preset_id]
    publish_all :destroy, [:preset_id]
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 2000, trim?: true
    end

    attribute :preset_version, :integer do
      description "The preset's version when this comment was posted."
      allow_nil? false
      public? true
      writable? false
      default 1
    end

    timestamps()
  end

  relationships do
    belongs_to :preset, Runeshare.Sharing.Preset do
      allow_nil? false
      public? true
    end

    belongs_to :author, Runeshare.Accounts.User do
      allow_nil? false
      public? true
    end
  end
end
