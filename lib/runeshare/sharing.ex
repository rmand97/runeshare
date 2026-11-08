defmodule Runeshare.Sharing do
  @moduledoc """
  Community-shared RuneScape 3 plugin presets: Watchdog alarm strings and tile marker presets.
  """

  use Ash.Domain, otp_app: :runeshare, extensions: [AshAdmin.Domain, AshPhoenix]

  alias Runeshare.Sharing.{Comment, ImportString, Like, Preset, TagCatalog}
  alias Runeshare.Sharing.Preset.Changes.{NormalizeTags, SnapshotVersion}
  alias Runeshare.Sharing.Preset.Validations.CoverImage

  admin do
    show? true
  end

  resources do
    resource Runeshare.Sharing.Preset do
      # Optional filters go in a params map: list_presets!(kind, %{search:, sort:, tag:}, opts).
      define :list_presets, action: :list, args: [:kind]

      define :list_sitemap_presets, action: :sitemap
      define :preset_stats, action: :stats
      define :list_liked_presets, action: :liked
      define :list_presets_by_author, action: :by_author, args: [:author_id]
      define :find_duplicate_presets, action: :duplicates, args: [:kind, :content]
      define :hide_preset, action: :hide
      define :unhide_preset, action: :unhide
      define :list_my_presets, action: :mine

      define :get_preset,
        action: :read,
        get_by: [:id],
        default_options: [
          load: [
            :author,
            :like_count,
            :comment_count,
            :copy_count,
            :cover_image_url,
            :liked_by_me
          ]
        ]

      define :share_preset, action: :share
      define :import_preset, action: :import
      define :edit_preset, action: :edit
      define :delete_preset, action: :destroy
    end

    resource Runeshare.Sharing.PresetVersion do
      define :list_preset_versions, action: :for_preset, args: [:preset_id]
      define :get_preset_version, action: :read, get_by: [:preset_id, :number]
    end

    resource Runeshare.Sharing.Report do
      # Optional note in a params map: report_preset!(preset_id, reason, %{note: ...}, opts).
      define :report_preset, action: :file, args: [:preset_id, :reason]
      define :list_open_reports, action: :open
      define :resolve_report, action: :resolve
      define :hide_reported_preset, action: :hide_preset
    end

    resource Runeshare.Sharing.Like do
      define :like_preset, action: :like, args: [:preset_id]
      define :unlike_preset, action: :unlike, get_by: [:preset_id, :user_id]
      define :set_like, action: :set, args: [:preset_id, :liked]
    end

    resource Runeshare.Sharing.Comment do
      define :list_comments, action: :for_preset, args: [:preset_id]

      define :get_comment,
        action: :read,
        get_by: [:id],
        default_options: [load: [:author, :removable_by_actor]]

      define :post_comment, action: :post, args: [:preset_id, :body]
      define :remove_comment, action: :remove
    end

    resource Runeshare.Sharing.StorageBlob
    resource Runeshare.Sharing.StorageAttachment

    resource Runeshare.Sharing.PresetCopy do
      define :record_copy, action: :record, args: [:preset_id, :visitor]
    end
  end

  # Real-time updates. Each resource owns its topics (beside its `pub_sub` block);
  # these are what the web layer subscribes through. Broadcasts carry no loads:
  # re-fetch through a code interface.

  @doc "Live updates for a listing of `kind`: presets shared, unhidden, deleted or hidden."
  @spec subscribe_to_kind(atom()) :: :ok
  defdelegate subscribe_to_kind(kind), to: Preset

  @doc "Live updates for one preset's page: the preset itself, its likes and its comments."
  @spec subscribe_to_preset(String.t()) :: :ok
  def subscribe_to_preset(preset_id) do
    Enum.each(preset_topics(), & &1.subscribe(preset_id))
  end

  @doc "Undoes `subscribe_to_preset/1`."
  @spec unsubscribe_from_preset(String.t()) :: :ok
  def unsubscribe_from_preset(preset_id) do
    Enum.each(preset_topics(), & &1.unsubscribe(preset_id))
  end

  defp preset_topics, do: [Preset, Like, Comment]

  # Rules the web layer needs outside an action: form hints, previews, URL
  # parsing. The logic lives with the resource it belongs to.

  @doc "Every supported preset kind."
  @spec preset_kinds() :: list(atom())
  defdelegate preset_kinds(), to: Preset, as: :kinds

  @doc "Whether `content` is a valid import string for `kind`, with the reason if not."
  @spec check_import_string(atom(), String.t()) :: :ok | {:error, String.t()}
  defdelegate check_import_string(kind, content), to: ImportString, as: :check

  @doc "A title read out of an import string (first alert / preset name), if it has one."
  @spec suggest_title(atom(), String.t()) :: String.t() | nil
  defdelegate suggest_title(kind, content), to: ImportString, as: :suggested_title

  @doc "The alerts in a Watchdog export, for the \"Alerts in this export\" panel."
  @spec watchdog_alerts(String.t()) :: list(map())
  defdelegate watchdog_alerts(content), to: ImportString, as: :watchdog_summary

  @doc "The plugin and schema version of a Watchdog export (`nil` if it isn't one)."
  @spec watchdog_versions(String.t()) ::
          %{plugin_version: String.t() | nil, schema_version: integer()} | nil
  defdelegate watchdog_versions(content), to: ImportString

  @doc "Tags as saving stores them: trimmed, lowercased, nicknames mapped, deduplicated."
  @spec normalize_tags(list(String.t())) :: list(String.t())
  defdelegate normalize_tags(tags), to: NormalizeTags, as: :normalize

  @doc "Catalogue tags matching what the user has typed so far."
  @spec suggest_tags(String.t()) :: list(String.t())
  defdelegate suggest_tags(text), to: TagCatalog, as: :suggest

  @doc "Largest accepted cover image, in bytes."
  @spec cover_image_max_bytes() :: pos_integer()
  defdelegate cover_image_max_bytes(), to: CoverImage, as: :max_bytes

  @doc "Seconds after a version's creation during which an edit updates it in place."
  @spec version_merge_window() :: non_neg_integer()
  defdelegate version_merge_window(), to: SnapshotVersion, as: :merge_window

  @doc "Whether saving this share/edit changeset writes a new version."
  @spec new_version?(Ash.Changeset.t()) :: boolean()
  defdelegate new_version?(changeset), to: SnapshotVersion

  @doc "Whether an edit now would update `version` in place instead of adding one."
  @spec amends_version?(Runeshare.Sharing.PresetVersion.t()) :: boolean()
  defdelegate amends_version?(version), to: SnapshotVersion, as: :amends?
end
