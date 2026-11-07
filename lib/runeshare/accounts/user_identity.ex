defmodule Runeshare.Accounts.UserIdentity do
  @moduledoc """
  A sign-in provider's account (strategy + its user id) linked to a user: one
  row per provider a user has signed in with (Google, GitHub, Discord, Twitch).
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
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end
end
