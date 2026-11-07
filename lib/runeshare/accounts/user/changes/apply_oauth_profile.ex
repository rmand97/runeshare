defmodule Runeshare.Accounts.User.Changes.ApplyOAuthProfile do
  @moduledoc """
  Copies email, display name and avatar from a sign-in provider's `user_info`
  (normalised OpenID-style claims from Assent) onto the user. Used by every
  `register_with_<provider>` action; `provider:` names it in error messages.

  Users are matched by email, so the same verified address signs into the same
  account from Google, GitHub or Discord. An address the provider hasn't
  verified is refused: otherwise anyone could claim an existing account (or an
  admin address) by putting its email on an unverified account elsewhere.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl Ash.Resource.Change
  def init(opts) do
    if is_binary(opts[:provider]),
      do: {:ok, opts},
      else: {:error, "provider: is required (e.g. \"Google\")"}
  end

  @impl Ash.Resource.Change
  def change(changeset, opts, _context) do
    user_info = Changeset.get_argument(changeset, :user_info)

    if verified_email?(user_info) do
      apply_profile(changeset, user_info)
    else
      Changeset.add_error(changeset,
        field: :user_info,
        message: "#{opts[:provider]} hasn't verified this account's email address"
      )
    end
  end

  # Most providers send a boolean; some token payloads send "true".
  defp verified_email?(%{"email" => email, "email_verified" => verified}) when is_binary(email),
    do: verified in [true, "true"]

  defp verified_email?(_user_info), do: false

  defp apply_profile(changeset, user_info) do
    email = user_info["email"]

    changeset
    |> Changeset.change_attributes(%{
      email: email,
      name: display_name(user_info["name"] || user_info["preferred_username"]),
      avatar_url: avatar_url(user_info["picture"])
    })
    |> Changeset.force_change_attribute(:role, role_for(email))
  end

  defp role_for(email) do
    admins = Application.get_env(:runeshare, :admin_emails, [])
    if String.downcase(email) in admins, do: :admin, else: :user
  end

  # Fit the provider's name (or username) into the display-name limits; drop it if it can't.
  defp display_name(name) when is_binary(name) do
    trimmed = name |> String.trim() |> String.slice(0, 40)
    if String.length(trimmed) >= 2, do: trimmed
  end

  defp display_name(_missing), do: nil

  # Discord users without an avatar come back as ".../avatars/<id>/" (no image hash).
  defp avatar_url("https://" <> _rest = url) do
    if String.ends_with?(url, "/"), do: nil, else: url
  end

  defp avatar_url(_missing), do: nil
end
