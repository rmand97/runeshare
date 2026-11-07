defmodule Runeshare.Secrets do
  @moduledoc """
  Runtime secrets for AshAuthentication: token signing, and the OAuth client of
  each sign-in provider (`config :runeshare, :<provider>_oauth`, see
  `config/runtime.exs`).
  """

  use AshAuthentication.Secret

  alias Runeshare.Accounts.User

  @config_keys %{
    google: :google_oauth,
    github: :github_oauth,
    discord: :discord_oauth,
    twitch: :twitch_oauth
  }
  @providers Map.keys(@config_keys)

  @impl AshAuthentication.Secret
  def secret_for([:authentication, :tokens, :signing_secret], User, _opts, _context) do
    Application.fetch_env(:runeshare, :token_signing_secret)
  end

  def secret_for([:authentication, :strategies, provider, :redirect_uri], User, _opts, _context)
      when provider in @providers do
    {:ok, oauth(provider, :redirect_uri) || RuneshareWeb.Endpoint.url() <> "/auth"}
  end

  def secret_for([:authentication, :strategies, provider, key], User, _opts, _context)
      when provider in @providers and key in [:client_id, :client_secret] do
    case oauth(provider, key) do
      value when value in [nil, ""] -> :error
      value -> {:ok, value}
    end
  end

  defp oauth(provider, key), do: Application.get_env(:runeshare, @config_keys[provider], [])[key]
end
