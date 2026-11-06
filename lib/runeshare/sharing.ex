defmodule Runeshare.Sharing do
  @moduledoc """
  Community-shared RuneScape 3 plugin presets: Watchdog alarm strings and tile marker presets.
  """

  use Ash.Domain, otp_app: :runeshare, extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Runeshare.Sharing.Preset do
      # Optional filters go in a params map: list_presets!(kind, %{search:, sort:, tag:}, opts).
      define :list_presets, action: :list, args: [:kind]

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
    end

    resource Runeshare.Sharing.Like do
      define :like_preset, action: :like, args: [:preset_id]
      define :unlike_preset, action: :unlike, get_by: [:preset_id, :user_id]
    end

    resource Runeshare.Sharing.Comment do
      define :list_comments, action: :for_preset, args: [:preset_id]
      define :get_comment, action: :read, get_by: [:id], default_options: [load: [:author]]
      define :post_comment, action: :post, args: [:preset_id, :body]
      define :remove_comment, action: :remove
    end

    resource Runeshare.Sharing.StorageBlob
    resource Runeshare.Sharing.StorageAttachment

    resource Runeshare.Sharing.PresetCopy do
      define :record_copy, action: :record, args: [:preset_id, :visitor]
    end
  end
end
