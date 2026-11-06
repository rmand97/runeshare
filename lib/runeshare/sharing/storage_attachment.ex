defmodule Runeshare.Sharing.StorageAttachment do
  @moduledoc """
  Links a `StorageBlob` to the preset it belongs to (its cover image).
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage.AttachmentResource]

  postgres do
    table "storage_attachments"
    repo Runeshare.Repo

    # AshStorage finds a preset's attachments before deleting it and purges them
    # after; the database only nils the link so that second step still works.
    references do
      reference :preset, on_delete: :nilify
    end
  end

  attachment do
    blob_resource(Runeshare.Sharing.StorageBlob)
    belongs_to_resource(:preset, Runeshare.Sharing.Preset)
  end

  attributes do
    uuid_primary_key :id
  end
end
