defmodule Runeshare.Sharing.PresetCopy do
  @moduledoc """
  One visitor copying one preset's import string. At most one per visitor and
  preset, so reloading the page and copying again doesn't inflate `copy_count`.

  `visitor` is `"user:<id>"` for signed-in users and `"anon:<id>"` for the
  random id kept in an anonymous visitor's session (`RuneshareWeb.Plugs.VisitorId`).
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "preset_copies"
    repo Runeshare.Repo

    references do
      reference :preset, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :record do
      description "Counts a copy, once per visitor. Copying again changes nothing."
      accept [:preset_id, :visitor]
      upsert? true
      upsert_identity :one_per_visitor
      upsert_fields []
      change Runeshare.Sharing.Changes.RequireVisiblePreset
    end
  end

  policies do
    # Anonymous visitors copy too; the visitor key comes from the server, not the client.
    policy action(:record) do
      authorize_if always()
    end

    # Only read through `Preset.copy_count`; `visitor` itself is private.
    policy action_type(:read) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :visitor, :string do
      allow_nil? false
      sensitive? true
      constraints max_length: 64
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :preset, Runeshare.Sharing.Preset do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :one_per_visitor, [:preset_id, :visitor]
  end
end
