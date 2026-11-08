defmodule Runeshare.Sharing.DiscordWatchdogAlarms.Entry do
  @moduledoc "Pieces every layout builds its presets from: credit, title, description."

  alias Runeshare.Sharing.DiscordWatchdogAlarms.{CodeBlocks, InlineJson}

  @doc "The poster's display name."
  @spec credit(map()) :: String.t()
  def credit(message),
    do: message["author"]["global_name"] || message["author"]["username"] || "someone"

  @doc "A title that fits the preset's 3–100 characters."
  @spec title(String.t() | nil) :: String.t()
  def title(title) do
    (title || "")
    |> String.trim()
    |> String.slice(0, 100)
    |> String.pad_trailing(3, ".")
  end

  @doc "A credit line linking to `link`, then the poster's words without the exports."
  @spec description(String.t(), String.t(), String.t() | nil) :: String.t()
  def description(link, credit, content) do
    credit_line = "Created by #{credit} on the Watchdog Discord (#{link})."
    text = CodeBlocks.strip(content || "")

    notes =
      text
      |> InlineJson.objects()
      |> Enum.reduce(text, &String.replace(&2, &1, ""))
      |> String.trim()
      |> String.trim_trailing(":")

    if notes == "",
      do: credit_line,
      else: credit_line <> "\n\n" <> String.slice(notes, 0, 2000 - String.length(credit_line) - 2)
  end
end
