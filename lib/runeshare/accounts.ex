defmodule Runeshare.Accounts do
  @moduledoc """
  Users and their Google sign-in identities.
  """

  use Ash.Domain, otp_app: :runeshare, extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Runeshare.Accounts.Token

    resource Runeshare.Accounts.User do
      define :update_profile, action: :update_profile
      define :get_user, action: :read, get_by: [:id]
    end

    resource Runeshare.Accounts.UserIdentity
  end
end
