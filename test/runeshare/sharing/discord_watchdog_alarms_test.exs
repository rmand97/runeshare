defmodule Runeshare.Sharing.DiscordWatchdogAlarmsTest do
  use Runeshare.DataCase, async: true

  import ExUnit.CaptureLog

  alias Req.Test, as: ReqTest
  alias Runeshare.Sharing
  alias Runeshare.Sharing.DiscordWatchdogAlarms

  @cdn "https://cdn.discordapp.com/attachments/1/2/alarm.json"

  # Real export, as shared in r/runescape's "Watchdog alerts" thread.
  @inventory_alert String.trim(~S"""
                   {"schemaVersion":1,"entries":[{"kind":"alert","enabled":true,"name":"Inventory nearly full (25 spaces used)","graph":{"version":1,"nodes":[{"controls":{"color":{"g":255,"r":20,"a":127,"b":0},"inShape":"instant","outShape":"instant","dismissOn":"both"},"id":7,"type":"action.screen_flash"},{"controls":{"condition":false},"id":9,"type":"std.branch"},{"controls":{"container":93},"id":11,"type":"trigger.inventory"},{"controls":{"operation":">=","a":0,"b":25},"id":16,"type":"std.compare"},{"controls":{"bus":"VOICEOVER","soundId":3964},"id":20,"type":"action.sound"},{"controls":{"theme":"parchment","hold":4.0,"body":"Inventory nearly full","title":"Inventory"},"id":37,"type":"action.popup"}],"connections":[{"toPin":"in","fromNode":9,"fromPin":"true","toNode":37},{"toPin":"show","fromNode":9,"fromPin":"true","toNode":7},{"toPin":"in","fromNode":9,"fromPin":"true","toNode":20},{"toPin":"in","fromNode":11,"fromPin":"out","toNode":9},{"toPin":"a","fromNode":11,"fromPin":"usedSlots","toNode":16},{"toPin":"condition","fromNode":16,"fromPin":"result","toNode":9}]},"layout":[{"x":1726,"id":7,"y":155},{"x":851,"id":9,"y":186},{"x":16,"id":11,"y":184},{"x":415,"id":16,"y":322},{"x":1486,"id":20,"y":419},{"x":1469,"id":37,"y":753}]}],"pluginVersion":"1.0.0"}
                   """)

  defp message(id, author, content, attachments \\ []) do
    %{
      "id" => id,
      "author" => %{
        "id" => "user-" <> String.downcase(author),
        "username" => String.downcase(author),
        "global_name" => author
      },
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

  # A forum channel's one post: started by Zezima, tagged Combat.
  defp archived(conn) do
    ReqTest.json(conn, %{
      "threads" => [
        %{
          "id" => "post-1",
          "parent_id" => "test-channel",
          "name" => "Boss timer",
          "owner_id" => "user-zezima",
          "applied_tags" => ["tag-combat"]
        }
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

    test "finds an export pasted inline after the poster's own words" do
      author = register_user!(email: "discord-inline@example.com")

      stub_discord(text_channel(), [
        message("1", "lc_steve", "With sound and popup:\n" <> @inventory_alert <> "\nEnjoy!")
      ])

      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-inline@example.com") end)

      assert %{"Inventory nearly full (25 spaces used)" => alarm} = alarms(author)
      assert alarm.content == @inventory_alert
      assert alarm.description =~ ~r/\(https:[^)]+\)\.\n\nWith sound and popup:\n+Enjoy!\z/
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
    defp forum do
      %{
        "id" => "test-channel",
        "guild_id" => "guild-1",
        "type" => 15,
        "available_tags" => [
          %{"id" => "tag-combat", "name" => "Combat"},
          %{"id" => "tag-skilling", "name" => "Skilling"}
        ]
      }
    end

    @message_txt "https://cdn.discordapp.com/attachments/1/2/message.txt"

    test "one preset per post: the creator's export, the post's title, opening words and tags" do
      author = register_user!(email: "discord-forum@example.com")
      boss_timer = watchdog_export("Boss timer alert")

      stub_discord(
        forum(),
        # Newest first, as Discord sends them.
        [
          message("4", "Durial", "My version: " <> watchdog_export("Durial timer")),
          message("3", "Zezima", "Too long to paste, so here it is as a file.", [
            %{"filename" => "message.txt", "url" => @message_txt, "size" => 4000}
          ]),
          message("2", "Zezima", "Screenshot of the graph:", [
            %{
              "filename" => "image.png",
              "url" => "https://cdn.discordapp.com/x.png",
              "size" => 120_000
            }
          ]),
          message("1", "Zezima", "Warns 10 seconds before the next boss phase.")
        ],
        %{@message_txt => boss_timer}
      )

      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-forum@example.com") end)

      assert [alarm] = Map.values(alarms(author))
      assert alarm.title == "Boss timer"
      assert alarm.content == boss_timer
      assert alarm.tags == ["discord", "combat"]

      assert alarm.description ==
               "Created by Zezima on the Watchdog Discord (https://discord.com/channels/guild-1/post-1)." <>
                 "\n\nWarns 10 seconds before the next boss phase."
    end

    test "a post with several alarms gets one preset each; a later export updates one" do
      author = register_user!(email: "discord-forum-many@example.com")
      newer_flash = String.replace(watchdog_export("Flash"), "1.0.0", "1.1.0")

      stub_discord(forum(), [
        message("3", "Zezima", "Fixed the flash: " <> newer_flash),
        message("2", "Zezima", code_block(watchdog_export("Sound"))),
        message("1", "Zezima", "Two alarms: " <> watchdog_export("Flash"))
      ])

      capture_log(fn -> DiscordWatchdogAlarms.sync_as("discord-forum-many@example.com") end)

      assert %{
               "Boss timer – Flash" => %{content: ^newer_flash},
               "Boss timer – Sound" => _sound
             } = alarms(author)
    end
  end
end
