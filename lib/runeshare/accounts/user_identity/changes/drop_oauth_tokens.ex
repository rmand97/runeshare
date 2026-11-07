defmodule Runeshare.Accounts.UserIdentity.Changes.DropOAuthTokens do
  @moduledoc """
  Keeps the provider's OAuth access and refresh tokens out of the database.
  AshAuthentication stores them on every sign-in, but RuneShare never calls a
  provider after sign-in, so they'd only be a liability if the database leaked.
  Runs as a `before_action` hook, after the library's own change has set them.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      Ash.Changeset.force_change_attributes(changeset, %{
        access_token: nil,
        refresh_token: nil,
        access_token_expires_at: nil
      })
    end)
  end
end
