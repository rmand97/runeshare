defmodule Runeshare.Secrets do
  @moduledoc """
  Runtime secrets for AshAuthentication: token signing and Google OAuth credentials.
  """

  use AshAuthentication.Secret

  alias Runeshare.Accounts.User

  @impl AshAuthentication.Secret
  def secret_for([:authentication, :tokens, :signing_secret], User, _opts, _context) do
    Application.fetch_env(:runeshare, :token_signing_secret)
  end

  def secret_for([:authentication, :strategies, :google, :redirect_uri], User, _opts, _context) do
    {:ok, google_oauth(:redirect_uri) || RuneshareWeb.Endpoint.url() <> "/auth"}
  end

  def secret_for([:authentication, :strategies, :google, key], User, _opts, _context)
      when key in [:client_id, :client_secret] do
    case google_oauth(key) do
      value when value in [nil, ""] -> :error
      value -> {:ok, value}
    end
  end

  defp google_oauth(key), do: Application.get_env(:runeshare, :google_oauth, [])[key]
end
