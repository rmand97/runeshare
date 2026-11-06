defmodule Runeshare.Accounts.UserIdentity do
  @moduledoc """
  Google `iss`/`sub` claims linked to a user. Returning users are matched on these, not on email.
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
