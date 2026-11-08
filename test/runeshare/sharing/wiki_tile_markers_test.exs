defmodule Runeshare.Sharing.WikiTileMarkersTest do
  use Runeshare.DataCase, async: true

  import ExUnit.CaptureLog

  alias Runeshare.Accounts
  alias Runeshare.Sharing
  alias Runeshare.Sharing.WikiTileMarkers

  @token_a "TM2ARVaYW1vcmFrIFA0IHNhZmUgdGlsZXMAAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYn"
  @token_b "TM2ARNSYWtzaGEgc2hhZG93IHRpbGVzAAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJw"
  @token_c "TM2AR5Gb3JpbnRocnkgRHVuZ2VvbiAtIEhlbGxob3VuZHPOAbQwgp4BAAAAAAAAAAAAAAAABQAA"

  # The shape of https://runescape.wiki/w/Guide:Tilemarkers?action=raw.
  defp wikitext(token_a \\ @token_a) do
    """
    This is a repository of tile presets created for the Tilemarkers plugin.

    ==Skilling==
    ===Agility===
    {| class="wikitable sortable"
    !Location
    !Author
    !Preview / TM2 Code
    |-
    |'''Anachronia''' agility

    Click the [[Surge|surge]] tiles.<br>Then dive.
    |Voijehna (RS Reddit)
    |{{Tilemarkers map|token=#{token_a}|align=center|zoom=1}}
    |-
    |Anachronia agility
    |Jome
    |{{Tilemarkers map|token=#{@token_b}|align=center}}
    |-
    |Broken row
    |Someone
    |{{Tilemarkers map|token=not-a-token}}
    |}
    ==PvM bosses==
    ===Raksha, the Shadow Colossus===
    {| class="wikitable sortable"
    !Location
    !Author
    !Preview / TM2 Code
    |-
    |Raksha arena
    |[[User:Mod|Mod]]
    |[[Raksha]]
    |{{Tilemarkers map|token=#{@token_c}}}
    |}
    """
  end

  defp stub_wiki(body) do
    Req.Test.stub(WikiTileMarkers, &Req.Test.text(&1, body))
  end

  defp wiki_presets(author) do
    author.id
    |> Sharing.list_presets_by_author!(actor: author)
    |> Map.new(&{&1.title, &1})
  end

  describe "parse/1" do
    test "reads each row's title, credited author, notes, token and section tags" do
      assert [first, second, raksha] = WikiTileMarkers.parse(wikitext())

      assert first.title == "Anachronia agility (Voijehna (RS Reddit))"
      assert first.content == @token_a
      assert first.tags == ["agility", "skilling", "rs-wiki"]

      assert first.description =~
               ~r/\ACreated by Voijehna \(RS Reddit\)\. From the RuneScape Wiki/

      assert first.description =~ "Click the surge tiles.\nThen dive."

      assert second.title == "Anachronia agility (Jome)"
      assert second.description =~ "Created by Jome."

      assert raksha.title == "Raksha arena"
      assert raksha.content == @token_c
      assert raksha.description =~ "Created by Mod."
      assert raksha.tags == ["raksha", "pvm", "rs-wiki"]
    end

    test "skips rows without a valid token" do
      refute Enum.any?(WikiTileMarkers.parse(wikitext()), &(&1.title =~ "Broken"))
    end
  end

  describe "sync/2" do
    test "creates the wiki's presets, then only touches what changed" do
      author = register_user!()

      assert %{created: 3, updated: 0, unchanged: 0} = WikiTileMarkers.sync(author, wikitext())
      assert %{created: 0, updated: 0, unchanged: 3} = WikiTileMarkers.sync(author, wikitext())

      changed = String.replace(wikitext(@token_b), "|Raksha arena", "|Raksha arena\nNew notes")
      assert %{created: 0, updated: 2, unchanged: 1} = WikiTileMarkers.sync(author, changed)

      presets = wiki_presets(author)
      assert map_size(presets) == 3

      updated = presets["Anachronia agility (Voijehna (RS Reddit))"]
      assert updated.content == @token_b
      assert updated.version == 2
      assert presets["Raksha arena"].description =~ "New notes"

      assert [%{note: "Synced from the RuneScape Wiki"} | _older] =
               Sharing.list_preset_versions!(updated.id, actor: author)
    end

    test "adds rows that are new on the wiki" do
      author = register_user!()
      [skilling_only, _pvm] = String.split(wikitext(), "==PvM bosses==")
      assert %{created: 2} = WikiTileMarkers.sync(author, skilling_only)

      assert %{created: 1, unchanged: 2} = WikiTileMarkers.sync(author, wikitext())
      assert Map.has_key?(wiki_presets(author), "Raksha arena")
    end

    test "is not held back by the share rate limit" do
      author = register_user!()
      for n <- 1..10, do: share_preset!(author, %{title: "Own preset #{n}"})

      assert %{created: 3, failed: 0} = WikiTileMarkers.sync(author, wikitext())
    end
  end

  describe "sync_as/1" do
    test "fetches the wiki and shares as the user with that address" do
      author = register_user!(email: "wiki-author@example.com")
      stub_wiki(wikitext())

      capture_log(fn -> WikiTileMarkers.sync_as("Wiki-Author@example.com") end)

      assert map_size(wiki_presets(author)) == 3
    end

    test "skips with a warning when nobody has that address" do
      stub_wiki(wikitext())

      assert capture_log(fn -> WikiTileMarkers.sync_as("nobody@example.com") end) =~
               "wiki tile markers not synced"
    end

    test "skips with a warning when the wiki is down" do
      author = register_user!(email: "wiki-down@example.com")
      Req.Test.stub(WikiTileMarkers, &Plug.Conn.send_resp(&1, 503, "down"))

      assert capture_log(fn -> WikiTileMarkers.sync_as("wiki-down@example.com") end) =~
               "HTTP 503"

      assert wiki_presets(author) == %{}
    end
  end

  describe "import_preset" do
    test "anonymous visitors cannot import" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.import_preset(%{kind: :tile_marker, title: "Nope", content: @token_a})
    end
  end

  describe "get_user_by_email" do
    test "finds the user, with their address readable" do
      user = register_user!(email: "lookup@example.com")

      assert {:ok, found} = Accounts.get_user_by_email("lookup@example.com")
      assert found.id == user.id
      assert to_string(found.email) == "lookup@example.com"
    end
  end
end
