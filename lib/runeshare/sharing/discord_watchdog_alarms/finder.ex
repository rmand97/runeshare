defmodule Runeshare.Sharing.DiscordWatchdogAlarms.Finder do
  @moduledoc """
  A way people share a Watchdog export in a Discord message. Each finder returns
  the candidate strings it sees; `DiscordWatchdogAlarms` merges them and keeps the
  valid exports. To support a new way of posting, add a finder to its list.
  """

  @doc "Candidate export strings in `message` (a Discord message map)."
  @callback exports(message :: map()) :: list(String.t())
end
