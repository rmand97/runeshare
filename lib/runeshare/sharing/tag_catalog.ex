defmodule Runeshare.Sharing.TagCatalog do
  @moduledoc """
  The standard RS3 tags (bosses, skills, activities) and their common
  nicknames. The share form suggests these; saving a preset rewrites a known
  nickname to its tag (`"zammy"` → `"zamorak"`, `"rc"` → `"runecrafting"`).
  Tags outside the list are still allowed.

  To add a tag or nickname, add it here.
  """

  @bosses ~w(
    amascut araxxor arch-glacor beastmaster-durzag croesus dragonkin-laboratory
    gate-of-elidinis giant-mole gregorovic helwyr kalphite-king kerapac
    nex nex-aod queen-black-dragon raksha rasial rise-of-the-six
    shadow-reef solak telos temple-of-aminishi twin-furies tzkal-zuk
    vindicta vorago yakamaru zamorak
  )

  @skills ~w(
    agility archaeology attack constitution construction cooking crafting
    defence divination dungeoneering farming firemaking fishing fletching
    herblore hunter invention magic mining necromancy prayer ranged
    runecrafting slayer smithing strength summoning thieving woodcutting
  )

  @activities ~w(
    afk clue-scrolls hard-mode melee minigame pvm skilling
  )

  @tags Enum.sort(@bosses ++ @skills ++ @activities)

  @aliases %{
    "aod" => "nex-aod",
    "angel-of-death" => "nex-aod",
    "rax" => "araxxor",
    "ag" => "arch-glacor",
    "glacor" => "arch-glacor",
    "bm" => "beastmaster-durzag",
    "durzag" => "beastmaster-durzag",
    "ed1" => "temple-of-aminishi",
    "ed2" => "dragonkin-laboratory",
    "ed3" => "shadow-reef",
    "furies" => "twin-furies",
    "greg" => "gregorovic",
    "hm" => "hard-mode",
    "kk" => "kalphite-king",
    "qbd" => "queen-black-dragon",
    "rots" => "rise-of-the-six",
    "vindy" => "vindicta",
    "yaka" => "yakamaru",
    "zammy" => "zamorak",
    "zuk" => "tzkal-zuk",
    "agi" => "agility",
    "att" => "attack",
    "clues" => "clue-scrolls",
    "con" => "construction",
    "const" => "constitution",
    "hp" => "constitution",
    "cook" => "cooking",
    "craft" => "crafting",
    "def" => "defence",
    "defense" => "defence",
    "div" => "divination",
    "dg" => "dungeoneering",
    "dung" => "dungeoneering",
    "farm" => "farming",
    "fm" => "firemaking",
    "fish" => "fishing",
    "fletch" => "fletching",
    "herb" => "herblore",
    "hunt" => "hunter",
    "inv" => "invention",
    "mage" => "magic",
    "necro" => "necromancy",
    "pray" => "prayer",
    "range" => "ranged",
    "rc" => "runecrafting",
    "smith" => "smithing",
    "str" => "strength",
    "summ" => "summoning",
    "thiev" => "thieving",
    "wc" => "woodcutting"
  }

  @doc "Every standard tag, alphabetically."
  @spec tags() :: list(String.t())
  def tags, do: @tags

  @doc """
  The standard form of a (normalised) tag: its alias target, or the tag itself.

      iex> Runeshare.Sharing.TagCatalog.canonical("zammy")
      "zamorak"
      iex> Runeshare.Sharing.TagCatalog.canonical("my-own-tag")
      "my-own-tag"
  """
  @spec canonical(String.t()) :: String.t()
  def canonical(tag), do: Map.get(@aliases, tag, tag)

  @doc """
  Up to `limit` standard tags for what the user typed: an exact alias first, then
  tags starting with it, then tags containing it.
  """
  @spec suggest(String.t(), pos_integer()) :: list(String.t())
  def suggest(text, limit \\ 8) do
    query = text |> String.trim() |> String.downcase() |> String.replace(~r/\s+/, "-")

    if query == "" do
      []
    else
      alias_hit = if Map.has_key?(@aliases, query), do: [@aliases[query]], else: []
      {prefix, rest} = Enum.split_with(@tags, &String.starts_with?(&1, query))
      contains = Enum.filter(rest, &String.contains?(&1, query))

      (alias_hit ++ prefix ++ contains) |> Enum.uniq() |> Enum.take(limit)
    end
  end
end
