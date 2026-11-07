defmodule Runeshare.Accounts.Strategies.Twitch do
  @moduledoc """
  "Sign in with Twitch" for AshAuthentication. Twitch speaks OpenID Connect, so
  this is the `oidc` strategy pre-set with `Assent.Strategy.Twitch`, which asks
  for the `email` and `email_verified` claims in the ID token.

  Use it as `twitch do ... end` under `authentication.strategies`, with this
  module in the resource's `extensions`.
  """

  # `use` comes before any alias (module layout), so the Dsl module is spelled out.
  # credo:disable-for-next-line Credo.Check.Design.AliasUsage
  use AshAuthentication.Strategy.Custom, entity: Runeshare.Accounts.Strategies.Twitch.Dsl.dsl()

  alias AshAuthentication.Strategy.Oidc

  defdelegate transform(strategy, dsl_state), to: Oidc.Transformer
  defdelegate verify(strategy, dsl_state), to: Oidc.Verifier
end
