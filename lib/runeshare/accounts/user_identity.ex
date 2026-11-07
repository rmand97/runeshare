defmodule Runeshare.Accounts.UserIdentity do
  @moduledoc """
  A sign-in provider's account (strategy + its user id) linked to a user: one
  row per provider a user has signed in with (Google, GitHub, Discord, Twitch).
  The provider's OAuth tokens are not kept (see `Changes.DropOAuthTokens`).
  """

  use Ash.Resource,
    otp_app: :runeshare,
    domain: Runeshare.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication.UserIdentity]

  user_identity do
    user_resource Runeshare.Accounts.User
  end

  postgres do
    table "user_identities"
    repo Runeshare.Repo

    # A deleted user takes their provider links with them.
    references do
      reference :user, on_delete: :delete
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  changes do
    change Runeshare.Accounts.UserIdentity.Changes.DropOAuthTokens, on: [:create, :update]
  end
end
