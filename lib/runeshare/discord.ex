defmodule Runeshare.Discord do
  @moduledoc """
  Read-only Discord REST client for the RuneShare bot
  (`config :runeshare, :discord_bot, token: ...`). Reads a channel's message
  history, or every post of a forum channel, plus small attachments.

  The bot needs the Message Content intent and, in the server, View Channel and
  Read Message History on the channel (invite permissions `66560`).
  """

  @api "https://discord.com/api/v10"
  @forum 15
  @page 100
  @max_pages 50

  @type message :: map()

  @doc "Whether a bot token is configured."
  @spec configured?() :: boolean()
  def configured?, do: token() not in [nil, ""]

  @doc """
  Every message in `channel_id`, oldest first, each with `"guild_id"` and
  `"channel_id"` set. For a forum channel, the messages of every post (active and
  archived), each with `"post"`: `%{"id", "name", "owner_id", "tags"}` (the post's
  forum tag names).
  """
  @spec channel_messages(String.t()) :: {:ok, list(message())} | {:error, term()}
  def channel_messages(channel_id) do
    case get("/channels/#{channel_id}") do
      {:ok, %{"type" => @forum} = forum} -> forum_messages(forum)
      {:ok, channel} -> history(channel)
      {:error, reason} -> {:error, reason}
    end
  end

  defp forum_messages(forum) do
    case get("/guilds/#{forum["guild_id"]}/threads/active") do
      {:ok, %{"threads" => active}} ->
        forum_messages(forum, Enum.filter(active, &(&1["parent_id"] == forum["id"])))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp forum_messages(forum, active) do
    case archived_threads(forum["id"], nil, []) do
      {:ok, archived} ->
        (active ++ archived)
        |> Enum.uniq_by(& &1["id"])
        |> Enum.reduce_while({:ok, []}, &read_post(&1, &2, forum))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_post(thread, {:ok, acc}, forum) do
    tag_names = Map.new(forum["available_tags"] || [], &{&1["id"], &1["name"]})

    post = %{
      "id" => thread["id"],
      "name" => thread["name"],
      "owner_id" => thread["owner_id"],
      "tags" => for(id <- thread["applied_tags"] || [], tag_names[id], do: tag_names[id])
    }

    case history(Map.put(thread, "guild_id", forum["guild_id"])) do
      {:ok, messages} -> {:cont, {:ok, acc ++ Enum.map(messages, &Map.put(&1, "post", post))}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp archived_threads(forum_id, before, acc) do
    params = Enum.reject([limit: @page, before: before], &is_nil(elem(&1, 1)))

    case get("/channels/#{forum_id}/threads/archived/public", params) do
      {:ok, %{"threads" => [_first | _rest] = threads, "has_more" => true}} ->
        last = List.last(threads)["thread_metadata"]["archive_timestamp"]
        archived_threads(forum_id, last, acc ++ threads)

      {:ok, %{"threads" => threads}} ->
        {:ok, acc ++ threads}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Newest first from the API, a page at a time; returned oldest first.
  defp history(channel, before \\ nil, acc \\ [], pages \\ 0)

  defp history(_channel, _before, acc, @max_pages), do: {:ok, acc}

  defp history(channel, before, acc, pages) do
    params = Enum.reject([limit: @page, before: before], &is_nil(elem(&1, 1)))

    case get("/channels/#{channel["id"]}/messages", params) do
      {:ok, []} ->
        {:ok, acc}

      {:ok, messages} ->
        located =
          messages
          |> Enum.reverse()
          |> Enum.map(
            &Map.merge(&1, %{"guild_id" => channel["guild_id"], "channel_id" => channel["id"]})
          )

        if Enum.count(messages) < @page,
          do: {:ok, located ++ acc},
          else: history(channel, List.last(messages)["id"], located ++ acc, pages + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "The body of an attachment (Discord's CDN URL), as text."
  @spec attachment(String.t()) :: {:ok, String.t()} | {:error, term()}
  def attachment(url) do
    case Req.get(url, [decode_body: false] ++ req_options()) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, "Discord CDN answered HTTP #{status}"}
      {:error, exception} -> {:error, exception}
    end
  end

  defp get(path, params \\ []) do
    request =
      [
        url: @api <> path,
        params: params,
        headers: [
          authorization: "Bot #{token()}",
          user_agent: "DiscordBot (https://runeshare.dk, 1.0)"
        ]
      ] ++ req_options()

    case Req.get(request) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, "Discord answered HTTP #{status} for #{path}"}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp token, do: Application.get_env(:runeshare, :discord_bot, [])[:token]
  defp req_options, do: Application.get_env(:runeshare, :discord_req_options, [])
end
