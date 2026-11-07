defmodule Runeshare.Accounts.Strategies.Discord do
  @moduledoc """
  "Sign in with Discord" for AshAuthentication, which ships no Discord strategy.
  Built like its own GitHub one: the `oauth2` strategy pre-set with
  `Assent.Strategy.Discord`, whose user info carries `email` and
  `email_verified` (Discord's `verified` flag).

  Use it as `discord do ... end` under `authentication.strategies`, with this
  module in the resource's `extensions`.
  """

  # `use` comes before any alias (module layout), so the Dsl module is spelled out.
  # credo:disable-for-next-line Credo.Check.Design.AliasUsage
  use AshAuthentication.Strategy.Custom, entity: Runeshare.Accounts.Strategies.Discord.Dsl.dsl()

  alias AshAuthentication.Strategy.OAuth2

  defdelegate transform(strategy, dsl_state), to: OAuth2
  defdelegate verify(strategy, dsl_state), to: OAuth2
end
