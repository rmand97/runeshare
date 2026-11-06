defmodule Runeshare.Sharing.PresetVersion do
  @moduledoc """
  A snapshot of a preset's title, description and import string. `number`
  counts up from 1; the highest number is the preset's current version.
  Older versions never change; the newest one is updated in place when its
  author edits again shortly after saving it (see `SnapshotVersion`).
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "preset_versions"
    repo Runeshare.Repo

    references do
      reference :preset, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    read :for_preset do
      description "Every version of a preset, newest first."
      argument :preset_id, :uuid, allow_nil?: false
      filter expr(preset_id == ^arg(:preset_id))
      prepare build(sort: [number: :desc])
    end

    create :snapshot do
      description "Only created through the preset's own share/edit actions."
      primary? true
      accept [:number, :title, :description, :content, :note]
    end

    update :amend do
      description "Only through the preset's edit action, for a quick re-edit of the newest version."
      accept [:title, :description, :content, :note]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if action_type(:read)
    end

    # A hidden preset's versions are as private as the preset itself.
    policy action_type(:read) do
      authorize_if expr(preset.hidden == false)
      authorize_if relates_to_actor_via([:preset, :author])
    end

    policy action_type([:create, :update]) do
      authorize_if accessing_from(Runeshare.Sharing.Preset, :versions)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :content, :string, allow_nil?: false, public?: true

    attribute :note, :string do
      description "What changed in this version, written by the author."
      public? true
      constraints max_length: 200
    end

    create_timestamp :inserted_at, public?: true
  end

  relationships do
    belongs_to :preset, Runeshare.Sharing.Preset do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_number, [:preset_id, :number]
  end
end
