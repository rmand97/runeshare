defmodule Runeshare.Sharing.DiscordWatchdogAlarms.ForumPosts do
  @moduledoc """
  Layout: a forum channel, one preset per post. Only the post
  creator's exports count (replies are discussion); the preset takes the post's
  title, its first message as description and its forum tags. A later export of
  the same alarm by the creator is an update; several alarms in one post become
  "Post title – alarm name".
  """

  @behaviour Runeshare.Sharing.DiscordWatchdogAlarms.Layout

  alias Runeshare.Sharing
  alias Runeshare.Sharing.DiscordWatchdogAlarms.Entry

  @impl true
  def handles?(message), do: Map.has_key?(message, "post")

  @impl true
  def entries(messages, exports) do
    messages
    |> Enum.chunk_by(& &1["post"]["id"])
    |> Enum.flat_map(&post_entries(&1, exports))
  end

  defp post_entries([%{"post" => post} = first | _rest] = messages, exports) do
    own = Enum.filter(messages, &(&1["author"]["id"] == post["owner_id"]))
    opening = List.first(own, first)
    credit = Entry.credit(opening)
    link = "https://discord.com/channels/#{first["guild_id"]}/#{post["id"]}"

    alarms =
      own
      |> Enum.flat_map(exports)
      |> Enum.reverse()
      |> Enum.uniq_by(&Sharing.suggest_title(:watchdog_alarm, &1))
      |> Enum.reverse()

    Enum.map(alarms, fn export ->
      title =
        case alarms do
          [_one] -> post["name"]
          _several -> "#{post["name"]} – #{Sharing.suggest_title(:watchdog_alarm, export)}"
        end

      %{
        title: Entry.title(title),
        credit: credit,
        description: Entry.description(link, credit, opening["content"]),
        content: export,
        tags: ["discord" | post["tags"]]
      }
    end)
  end
end
