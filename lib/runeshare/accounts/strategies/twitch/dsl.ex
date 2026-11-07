defmodule Runeshare.Accounts.Strategies.Twitch.Dsl do
  @moduledoc false

  alias AshAuthentication.Strategy.{Custom, Oidc}
  alias Assent.Strategy.Twitch

  @doc false
  @spec dsl() :: Custom.entity()
  def dsl do
    Oidc.dsl()
    |> Map.merge(%{
      name: :twitch,
      args: [{:optional, :name, :twitch}],
      describe: "Sign in with Twitch, through the `oidc` strategy.",
      auto_set_fields: [icon: :twitch, assent_strategy: Twitch]
    })
    |> Custom.set_defaults(Twitch.default_config([]))
    |> Custom.set_defaults(trust_email_verified?: true)
  end
end
