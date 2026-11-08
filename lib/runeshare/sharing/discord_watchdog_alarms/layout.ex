defmodule Runeshare.Sharing.DiscordWatchdogAlarms.Layout do
  @moduledoc """
  A way a channel is organised, turning its messages into presets. Each message
  goes to the first layout in `DiscordWatchdogAlarms`'s list that `handles?/1` it.
  """

  @doc "Whether this layout reads `message`."
  @callback handles?(message :: map()) :: boolean()

  @doc """
  Presets for `messages` (oldest first). `exports` finds the valid exports in one
  message.
  """
  @callback entries(messages :: list(map()), exports :: (map() -> list(String.t()))) ::
              list(Runeshare.Sharing.PresetSync.entry())
end
