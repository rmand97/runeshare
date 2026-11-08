defmodule Runeshare.Sharing.DiscordWatchdogAlarmsTest do
  use Runeshare.DataCase, async: true

  import ExUnit.CaptureLog

  alias Req.Test, as: ReqTest
  alias Runeshare.Sharing
  alias Runeshare.Sharing.DiscordWatchdogAlarms

  @cdn "https://cdn.discordapp.com/attachments/1/2/alarm.json"

  defp message(id, author, content, attachments \\ []) do
    %{
      "id" => id,
      "author" => %{"username" => String.downcase(author), "global_name" => author},
      "content" => content,
      "attachments" => attachments
    }
  end

  defp code_block(json), do: "```json\n#{json}\n```"

  # Answers like Discord's API for a text channel holding `messages` (newest first,
  # as Discord sends them) and serves `files` from the CDN.
  defp stub_discord(channel, messages, files \\ %{}) do
    ReqTest.stub(Runeshare.Discord, fn conn ->
      case conn.request_path do
        "/api/v10/channels/test-channel" -> ReqTest.json(conn, channel)
        "/api/v10/channels/test-channel/messages" -> ReqTest.json(conn, messages)
        "/api/v10/guilds/guild-1/threads/active" -> ReqTest.json(conn, %{"threads" => []})
        "/api/v10/channels/test-channel/threads/archived/public" -> archived(conn)
        "/api/v10/channels/post-1/messages" -> ReqTest.json(conn, messages)
        path -> ReqTest.text(conn, Map.fetch!(files, "https://cdn.discordapp.com" <> path))
      end
    end)
  end

  defp archived(conn) do
    ReqTest.json(conn, %{
      "threads" => [
        %{"id" => "post-1", "parent_id" => "test-channel", "name" => "Croesus alarms"}
      ],
      "has_more" => false
    })
  end

  defp text_channel, do: %{"id" => "test-channel", "guild_id" => "guild-1", "type" => 0}

  defp alarms(author) do
    author.id
    |> Sharing.list_presets_by_author!(actor: author)
    |> Map.new(&{&1.title, &1})
  end

  describe "sync_as/1, text channel" do
    test "shares every alarm export, credited to its poster with a link" do
      author = register_user!(email: "discord-import@example.com")

      stub_discord(
        text_channel(),
        [
          message("3", "Mod Ash", "Not an alarm, just chatting"),
          message("2", "Durial", "", [
            %{"filename" => "alarm.json", "url" => @cdn, "size" => 300}
          ]),
          message("1", "Zezima", "Prayer alarm, enjoy\n" <> code_block(watchdog_export("Prayer")))
        ],
        %{@cdn => watchdog_export("Telos enrage")}
      )

      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-import@example.com") end)

      assert %{"Prayer" => prayer, "Telos enrage" => telos} = alarms(author)
      assert prayer.kind == :watchdog_alarm
      assert prayer.content == watchdog_export("Prayer")

      assert prayer.description ==
               "Created by Zezima on the Watchdog Discord " <>
                 "(https://discord.com/channels/guild-1/test-channel/1).\n\nPrayer alarm, enjoy"

      assert telos.description =~ "Created by Durial"
      assert prayer.tags == ["discord"]
    end

    test "a second run changes nothing; an edited post updates the preset" do
      author = register_user!(email: "discord-rerun@example.com")
      post = fn json -> [message("1", "Zezima", code_block(json))] end

      stub_discord(text_channel(), post.(watchdog_export("Prayer")))
      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-rerun@example.com") end)

      assert capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-rerun@example.com") end) =~
               "unchanged: 1"

      edited = String.replace(watchdog_export("Prayer"), ~s("enabled":true), ~s("enabled":false))
      stub_discord(text_channel(), post.(edited))
      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-rerun@example.com") end)

      assert %{"Prayer" => %{content: ^edited, version: 2}} = alarms(author)
    end

    test "when someone reposts an alarm, the newest post wins" do
      author = register_user!(email: "discord-repost@example.com")
      newer = String.replace(watchdog_export("Prayer"), "1.0.0", "1.1.0")

      stub_discord(text_channel(), [
        message("2", "Zezima", code_block(newer)),
        message("1", "Zezima", code_block(watchdog_export("Prayer")))
      ])

      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-repost@example.com") end)

      assert %{"Prayer" => %{content: ^newer}} = alarms(author)
    end

    test "the same alarm name from two people gets each poster in brackets" do
      author = register_user!(email: "discord-twins@example.com")

      stub_discord(text_channel(), [
        message("2", "Durial", code_block(watchdog_export("Prayer"))),
        message("1", "Zezima", code_block(watchdog_export("Prayer")))
      ])

      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-twins@example.com") end)

      assert Map.keys(alarms(author)) |> Enum.sort() == ["Prayer (Durial)", "Prayer (Zezima)"]
    end

    test "skips with a warning when Discord refuses the bot" do
      author = register_user!(email: "discord-refused@example.com")
      ReqTest.stub(Runeshare.Discord, &Plug.Conn.send_resp(&1, 403, "Missing Access"))

      assert capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-refused@example.com") end) =~
               "HTTP 403"

      assert alarms(author) == %{}
    end
  end

  describe "sync_as/1, forum channel" do
    test "reads every post and titles alarms by the post's title" do
      author = register_user!(email: "discord-forum@example.com")

      stub_discord(%{"id" => "test-channel", "guild_id" => "guild-1", "type" => 15}, [
        message("10", "Zezima", code_block(watchdog_export("Harp tune")))
      ])

      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-forum@example.com") end)

      assert %{"Croesus alarms" => alarm} = alarms(author)
      assert alarm.description =~ "https://discord.com/channels/guild-1/post-1/10"
    end
  end
end
