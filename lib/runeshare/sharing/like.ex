defmodule Runeshare.Sharing.Like do
  @moduledoc """
  One user liking one preset. At most one per user and preset.
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Sharing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "likes"
    repo Runeshare.Repo

    references do
      reference :preset, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :like do
      accept [:preset_id]
      upsert? true
      upsert_identity :unique_like
      upsert_fields []
      change relate_actor(:user, allow_nil?: true)
      change Runeshare.Sharing.Changes.RequireVisiblePreset
    end

    destroy :unlike do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if action_type(:read)
    end

    # A hidden preset's likes are as private as the preset itself.
    policy action_type(:read) do
      authorize_if expr(preset.hidden == false)
      authorize_if relates_to_actor_via([:preset, :author])
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  pub_sub do
    module RuneshareWeb.Endpoint
    prefix "likes"
    publish_all :create, [:preset_id]
    publish_all :destroy, [:preset_id]
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :preset, Runeshare.Sharing.Preset do
      allow_nil? false
      public? true
    end

    belongs_to :user, Runeshare.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_like, [:preset_id, :user_id]
  end
end
