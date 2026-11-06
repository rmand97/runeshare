defmodule Runeshare.Sharing.StorageBlob do
  @moduledoc """
  A stored file (key, size, content type, checksum), managed by AshStorage.
  Created and purged only through `Preset`'s `cover_image` attachment.
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage.BlobResource]

  postgres do
    table "storage_blobs"
    repo Runeshare.Repo
  end

  blob do
  end

  attributes do
    uuid_primary_key :id
  end
end
