defmodule Runeshare.Accounts.User.Changes.ApplyGoogleProfile do
  @moduledoc """
  Copies email, display name and avatar from Google's `user_info` claims onto the user.

  Users are matched by email, so an address Google hasn't verified is refused:
  otherwise anyone could claim an existing account (or an admin address) by
  putting its email on an unverified Google account.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    user_info = Changeset.get_argument(changeset, :user_info)

    if verified_email?(user_info) do
      apply_profile(changeset, user_info)
    else
      Changeset.add_error(changeset,
        field: :user_info,
        message: "Google hasn't verified this account's email address"
      )
    end
  end

  # Google's userinfo endpoint sends a boolean; some token payloads send "true".
  defp verified_email?(%{"email_verified" => verified}), do: verified in [true, "true"]
  defp verified_email?(_user_info), do: false

  defp apply_profile(changeset, user_info) do
    email = user_info["email"]

    changeset
    |> Changeset.change_attributes(%{
      email: email,
      name: display_name(user_info["name"]),
      avatar_url: user_info["picture"]
    })
    |> Changeset.force_change_attribute(:role, role_for(email))
  end

  defp role_for(email) when is_binary(email) do
    admins = Application.get_env(:runeshare, :admin_emails, [])
    if String.downcase(email) in admins, do: :admin, else: :user
  end

  defp role_for(_email), do: :user

  # Fit Google's full name into the display-name limits; drop it if it can't.
  defp display_name(name) when is_binary(name) do
    trimmed = name |> String.trim() |> String.slice(0, 40)
    if String.length(trimmed) >= 2, do: trimmed
  end

  defp display_name(_missing), do: nil
end
