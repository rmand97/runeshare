defmodule Runeshare.Accounts do
  @moduledoc """
  Users and their sign-in identities (Google, GitHub, Discord, Twitch).
  """

  use Ash.Domain, otp_app: :runeshare, extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  alias Runeshare.Accounts.User

  resources do
    resource Runeshare.Accounts.Token

    resource Runeshare.Accounts.User do
      define :update_profile, action: :update_profile
      define :delete_account, action: :destroy_account
      define :get_user, action: :read, get_by: [:id]

      define :get_author,
        action: :read,
        get_by: [:id],
        default_options: [load: [:share_count, :total_likes, :total_copies]]
    end

    resource Runeshare.Accounts.UserIdentity
  end

  @doc "Whether `user` is a moderator (`role: :admin`). `nil` (signed out) is not."
  @spec admin?(User.t() | nil) :: boolean()
  defdelegate admin?(user), to: User
end
