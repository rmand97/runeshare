defmodule Runeshare.Sharing.DiscordWatchdogAlarms.CodeBlocks do
  @moduledoc "Finder: exports in fenced code blocks (```json ... ```)."

  @behaviour Runeshare.Sharing.DiscordWatchdogAlarms.Finder

  @code_block ~r/```[a-z]*\s*(.*?)```/s

  @impl true
  def exports(message),
    do: for([_match, block] <- Regex.scan(@code_block, text(message)), do: block)

  @doc "`text` without its code blocks."
  @spec strip(String.t()) :: String.t()
  def strip(text), do: String.replace(text, @code_block, "")

  defp text(message), do: message["content"] || ""
end
