defmodule Runeshare.Sharing.Report do
  @moduledoc """
  A user flagging a preset for moderators. One open report per user and preset;
  reporting again updates the reason.
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    simple_notifiers: [Runeshare.ActionLog.Notifier]

  postgres do
    table "reports"
    repo Runeshare.Repo

    references do
      reference :preset, on_delete: :delete
      reference :reporter, on_delete: :delete
    end

    custom_indexes do
      index [:status, :inserted_at]
    end
  end

  actions do
    defaults [:read]

    read :open do
      description "Unresolved reports, oldest first, with preset and reporter."
      filter expr(status == :open)
      prepare build(sort: [inserted_at: :asc], load: [:reporter, preset: [:author]])
      pagination offset?: true, countable: true, required?: false, default_limit: 20
    end

    create :file do
      accept [:preset_id, :reason, :note]
      upsert? true
      upsert_identity :one_per_reporter
      upsert_fields [:reason, :note, :status, :updated_at]
      change relate_actor(:reporter, allow_nil?: true)
      change set_attribute(:status, :open)
    end

    update :resolve do
      accept []
      change set_attribute(:status, :resolved)
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action(:file) do
      authorize_if actor_present()
    end

    # Reports are moderator-only beyond filing (admins pass the bypass above).
    policy action_type([:read, :update]) do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reason, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:spam, :broken, :offensive, :other]
    end

    attribute :note, :string do
      public? true
      constraints max_length: 500, trim?: true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :open
      constraints one_of: [:open, :resolved]
    end

    timestamps()
  end

  relationships do
    belongs_to :preset, Runeshare.Sharing.Preset do
      allow_nil? false
      public? true
    end

    belongs_to :reporter, Runeshare.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :one_per_reporter, [:preset_id, :reporter_id]
  end
end
