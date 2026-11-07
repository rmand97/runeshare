defmodule Runeshare.Repo.Migrations.ClearStoredOauthTokens do
  @moduledoc """
  Clears the provider OAuth tokens stored before `DropOAuthTokens` stopped
  keeping them. Data only; the columns stay (AshAuthentication defines them).
  """

  use Ecto.Migration

  def up do
    execute """
    UPDATE user_identities
    SET access_token = NULL, refresh_token = NULL, access_token_expires_at = NULL
    """
  end

  # The tokens are gone; there is nothing to restore.
  def down, do: :ok
end
