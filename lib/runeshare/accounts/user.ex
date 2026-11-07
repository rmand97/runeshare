defmodule Runeshare.Accounts.User do
  @moduledoc """
  A person signed in with Google. Created on first sign-in, refreshed on each one after.
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication],
    simple_notifiers: [Runeshare.ActionLog.Notifier]

  authentication do
    tokens do
      enabled? true
      token_resource Runeshare.Accounts.Token
      signing_secret Runeshare.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      google do
        client_id Runeshare.Secrets
        redirect_uri Runeshare.Secrets
        client_secret Runeshare.Secrets
        identity_resource Runeshare.Accounts.UserIdentity
      end
    end
  end

  postgres do
    table "users"
    repo Runeshare.Repo
  end

  field_policies do
    field_policy_bypass :* do
      authorize_if AshAuthentication.Checks.AshAuthenticationInteraction
    end

    field_policy :email do
      authorize_if expr(id == ^actor(:id))
    end

    field_policy :* do
      authorize_if always()
    end
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    update :update_profile do
      description "The signed-in user changing their own display name."
      accept [:name]
    end

    create :register_with_google do
      description "Sign in or register a user with Google."
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false, sensitive?: true
      upsert? true
      upsert_identity :unique_email
      # `name` is only taken from Google on first sign-in; afterwards it's the
      # user's own display name, edited on the account page.
      # `role` follows ADMIN_EMAILS on every sign-in, so removing an address demotes it.
      upsert_fields [:email, :avatar_url, :role]

      change AshAuthentication.GenerateTokenChange
      change AshAuthentication.Strategy.OAuth2.IdentityChange
      change Runeshare.Accounts.User.Changes.ApplyGoogleProfile
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Display name and avatar appear next to everything a user shares.
    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      public? true
      constraints min_length: 2, max_length: 40, trim?: true
    end

    attribute :role, :atom do
      description "`:admin` for addresses in ADMIN_EMAILS; set on every sign-in."
      allow_nil? false
      public? true
      default :user
      writable? false
      constraints one_of: [:user, :admin]
    end

    attribute :avatar_url, :string do
      public? true
      constraints max_length: 2048
    end

    timestamps()
  end

  relationships do
    has_many :presets, Runeshare.Sharing.Preset do
      destination_attribute :author_id
      public? true
    end
  end

  # Profile totals. Preset read policies apply, so hidden presets only count
  # for their author and moderators.
  aggregates do
    count :share_count, :presets do
      public? true
    end

    count :total_likes, [:presets, :likes] do
      public? true
    end

    count :total_copies, [:presets, :copies] do
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  @doc "Whether `user` is a moderator. `nil` (signed out) is not."
  @spec admin?(t() | nil) :: boolean()
  def admin?(%__MODULE__{role: :admin}), do: true
  def admin?(_user), do: false
end
