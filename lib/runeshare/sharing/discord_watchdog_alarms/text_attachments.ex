defmodule Runeshare.Sharing.DiscordWatchdogAlarms.TextAttachments do
  @moduledoc """
  Finder: exports attached as `.json`/`.txt` files, including the `message.txt`
  Discord makes of a message too long to send.
  """

  @behaviour Runeshare.Sharing.DiscordWatchdogAlarms.Finder

  alias Runeshare.Discord

  @extensions [".json", ".txt"]
  @max_bytes 100_000

  @impl true
  def exports(message) do
    for %{"filename" => name, "url" => url, "size" => size} <- message["attachments"] || [],
        Path.extname(name) in @extensions,
        size <= @max_bytes,
        {:ok, body} <- [Discord.attachment(url)],
        do: body
  end
end
