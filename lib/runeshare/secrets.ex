defmodule Runeshare.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Runeshare.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:runeshare, :token_signing_secret)
  end
end
