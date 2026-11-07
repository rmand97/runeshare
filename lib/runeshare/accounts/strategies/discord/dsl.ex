defmodule Runeshare.Accounts.Strategies.Discord.Dsl do
  @moduledoc false

  alias AshAuthentication.Strategy.{Custom, OAuth2}
  alias Assent.Strategy.Discord

  @doc false
  @spec dsl() :: Custom.entity()
  def dsl do
    OAuth2.dsl()
    |> Map.merge(%{
      name: :discord,
      args: [{:optional, :name, :discord}],
      describe: "Sign in with Discord, through the `oauth2` strategy.",
      auto_set_fields: [icon: :discord, assent_strategy: Discord]
    })
    |> Custom.set_defaults(Discord.default_config([]))
    # Assent still points at the legacy discordapp.com host.
    |> Custom.set_defaults(base_url: "https://discord.com/api", trust_email_verified?: true)
  end
end
