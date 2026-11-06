# Fills the local dev database with a lot of realistic-looking data, to see how
# the UI copes with many presets, long names, many versions, comments and reports.
#
#     mix run priv/repo/demo_data.exs           # load (skips if already loaded)
#     mix run priv/repo/demo_data.exs --reset   # remove the demo data
#
# Dev only. Everything goes through the normal actions (validations, versions,
# rate limits), so demo users each share at most 10 presets.

alias Runeshare.Accounts.User
alias Runeshare.Sharing

if Mix.env() != :dev, do: Mix.raise("demo_data.exs only runs in dev")

# Keep every edit as its own version, so presets get long version lists.
Application.put_env(:runeshare, :version_merge_window_seconds, 0)

:rand.seed(:exsss, {2026, 11, 7})

demo_email = fn n -> "demo-#{n}@example.com" end
user_count = 60

register = fn n, name ->
  User
  |> Ash.Changeset.for_create(
    :register_with_google,
    %{
      user_info: %{
        "sub" => "demo-#{n}",
        "iss" => "https://accounts.google.com",
        "email" => demo_email.(n),
        "email_verified" => true,
        "name" => name
      },
      oauth_tokens: %{}
    },
    context: %{private: %{ash_authentication?: true}}
  )
  |> Ash.create!()
end

prefixes = ~w(Iron Dark Lost Silent Crimson Elder Hollow Grim Swift Lucky Frozen Golden Shadow Ancient Rune)
suffixes = ~w(Slayer Archer Mage Smith Hunter Warden Pker Skiller Knight Seeker Reaper Fisher Raider Tank)

names =
  for n <- 1..user_count do
    case rem(n, 9) do
      0 -> String.slice("The #{Enum.random(prefixes)} #{Enum.random(suffixes)} of Gielinor Who Never Logs Out", 0, 40)
      1 -> "#{Enum.random(prefixes)}#{Enum.random(suffixes)}#{:rand.uniform(999)}"
      2 -> "#{Enum.random(suffixes)} #{Enum.random(prefixes)}"
      _ -> "#{Enum.random(prefixes)} #{Enum.random(suffixes)}"
    end
  end

# Signing in again never overwrites a name, so this is safe to repeat.
users = for {name, n} <- Enum.with_index(names, 1), do: register.(n, name)

if "--reset" in System.argv() do

  removed =
    for user <- users, preset <- Sharing.list_my_presets!(actor: user), reduce: 0 do
      count ->
        Sharing.delete_preset!(preset, actor: user)
        count + 1
    end

  IO.puts("Removed #{removed} demo presets (the #{user_count} demo users stay; they're harmless).")
  System.halt(0)
end

if Sharing.list_my_presets!(actor: hd(users)) != [] do
  IO.puts("Demo data is already loaded. Run with --reset to remove it first.")
  System.halt(0)
end

# -- Words -------------------------------------------------------------------

bosses = ~w(Vorago Telos Zamorak Araxxor Raksha Solak Rasial Amascut Kerapac Vindicta Gregorovic Helwyr Croesus Nex) ++
           ["Arch-Glacor", "TzKal-Zuk", "Twin Furies", "Kalphite King", "Queen Black Dragon", "Angel of Death"]

skills = ~w(Mining Fishing Woodcutting Divination Archaeology Necromancy Runecrafting Hunter Farming Slayer Herblore Invention)

watchdog_titles = [
  "~s enrage timer",
  "~s phase alarms",
  "~s special attack warning",
  "Low prayer warning for ~s",
  "~s rotation timer",
  "~s hard mode full kit",
  "AFK ~s — XP drop alarm",
  "~s: every mechanic, every phase, colour-coded screen flashes and sounds for each",
  "~s bladed dive + ice prison + bomb warnings (melee & necro)"
]

tile_titles = [
  "~s safe tiles",
  "~s P4 positioning",
  "~s solo route",
  "~s bomb tiles",
  "~s minimal movement setup",
  "Learner ~s tiles with every walk-run spot marked for duo and trio",
  "~s — full fight, all phases"
]

descriptions = [
  nil,
  nil,
  "Works for solo and duo.",
  "Tested on the latest update. Tweak the sound volume to taste.",
  "Pings 10 seconds before each switch. Built for necromancy but works with any style.",
  String.duplicate("Long explanation of every phase, what each alert means and how to tune it. ", 12)
]

tag_pool = Sharing.TagCatalog.tags() ++ ~w(learner hm duo trio afk-friendly)

pick_tags = fn subject ->
  base = subject |> String.downcase() |> String.replace(~r/\s+/, "-")
  extra = Enum.take_random(tag_pool, :rand.uniform(4) - 1)
  Enum.take(Enum.uniq([base | extra]), 5)
end

# -- Content -----------------------------------------------------------------

node_types = ~w(trigger.xp_drop trigger.npc_spawn trigger.chat_message trigger.hp_below action.sound action.screen_flash action.notify)

watchdog_export = fn title ->
  entries =
    for i <- 1..(:rand.uniform(6)) do
      nodes =
        for id <- 1..(:rand.uniform(5) + 1) do
          %{"id" => id, "type" => Enum.random(node_types), "controls" => %{}}
        end

      %{
        "enabled" => true,
        "kind" => "alert",
        "name" => if(i == 1, do: title, else: "#{title} — part #{i}"),
        "graph" => %{"version" => 1, "nodes" => nodes, "connections" => []},
        "layout" => []
      }
    end

  JSON.encode!(%{"schemaVersion" => 1, "pluginVersion" => "1.0.0", "entries" => entries})
end

tile_token = fn title ->
  name = String.slice(title, 0, 60)
  tiles = :crypto.strong_rand_bytes(20 + :rand.uniform(600))
  "TM2" <> Base.url_encode64(<<1, byte_size(name), name::binary, tiles::binary>>, padding: false)
end

# Cover images: tile-grid pictures with a few "marked" tiles, in varied palettes
# and shapes (16:9, very wide, tall, square, tiny) to see how layouts cope.
png = fn width, height, pixel ->
  rows =
    for y <- 0..(height - 1), into: <<>> do
      <<0, (for x <- 0..(width - 1), into: <<>>, do: pixel.(x, y))::binary>>
    end

  chunk = fn type, data ->
    <<byte_size(data)::32, type::binary, data::binary, :erlang.crc32(type <> data)::32>>
  end

  <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>> <>
    chunk.("IHDR", <<width::32, height::32, 8, 2, 0, 0, 0>>) <>
    chunk.("IDAT", :zlib.compress(rows)) <> chunk.("IEND", <<>>)
end

palettes = [
  {{40, 52, 34}, {214, 170, 60}},
  {{30, 36, 58}, {90, 200, 250}},
  {{58, 28, 30}, {240, 90, 70}},
  {{36, 46, 46}, {120, 230, 160}},
  {{48, 38, 60}, {200, 120, 240}},
  {{60, 54, 40}, {250, 240, 200}}
]

shapes = [{960, 540}, {1200, 400}, {540, 900}, {700, 700}, {240, 135}, {800, 450}]
image_dir = Path.join(System.tmp_dir!(), "runeshare-demo-images")
File.mkdir_p!(image_dir)

covers =
  for {{width, height}, i} <- Enum.with_index(shapes), {{bg, mark}, j} <- Enum.with_index(palettes), rem(i + j, 3) == 0 do
    cell = 24
    marked = MapSet.new(for _ <- 1..18, do: {:rand.uniform(div(width, cell)), :rand.uniform(div(height, cell))})

    pixel = fn x, y ->
      {r, g, b} = bg
      shade = div(y * 40, height)
      cond do
        MapSet.member?(marked, {div(x, cell) + 1, div(y, cell) + 1}) and rem(x, cell) > 2 and rem(y, cell) > 2 ->
          {mr, mg, mb} = mark
          <<mr, mg, mb>>

        rem(x, cell) == 0 or rem(y, cell) == 0 ->
          <<min(r + 30, 255), min(g + 30, 255), min(b + 30, 255)>>

        true ->
          <<min(r + shade, 255), min(g + shade, 255), min(b + shade, 255)>>
      end
    end

    path = Path.join(image_dir, "cover-#{width}x#{height}-#{j}.png")
    File.write!(path, png.(width, height, pixel))
    %Plug.Upload{path: path, filename: Path.basename(path), content_type: "image/png"}
  end

IO.puts("Generated #{length(covers)} cover images.")

# -- Presets -----------------------------------------------------------------

per_kind = 250

specs =
  for kind <- [:watchdog_alarm, :tile_marker], n <- 1..per_kind do
    subject = if kind == :tile_marker or rem(n, 4) != 0, do: Enum.random(bosses), else: Enum.random(skills)
    template = Enum.random(if kind == :watchdog_alarm, do: watchdog_titles, else: tile_titles)
    title = template |> String.replace("~s", subject) |> String.slice(0, 100)
    {kind, n, subject, title}
  end

# Each demo user shares at most 9 (the share rate limit is 10 an hour).
presets =
  specs
  |> Enum.with_index()
  |> Enum.map(fn {{kind, n, subject, title}, i} ->
    author = Enum.at(users, rem(i, user_count))
    content = if kind == :watchdog_alarm, do: watchdog_export.(title), else: tile_token.(title)

    attrs = %{
      kind: kind,
      title: title,
      description: Enum.random(descriptions),
      content: content,
      tags: pick_tags.(subject)
    }

    attrs =
      if rem(n, 3) == 0,
        do: Map.put(attrs, :cover_image, Enum.at(covers, rem(div(n, 3), length(covers)))),
        else: attrs
    {Sharing.share_preset!(attrs, actor: author), author}
  end)

IO.puts("Shared #{length(presets)} presets.")
author_of = Map.new(presets, fn {preset, author} -> {preset.id, author} end)
presets = Enum.map(presets, &elem(&1, 0))

# -- Versions: a few presets with long histories -----------------------------

for preset <- Enum.take_random(presets, 12), author = author_of[preset.id] do
  Enum.reduce(2..(5 + :rand.uniform(12)), preset, fn v, current ->
    Sharing.edit_preset!(
      current,
      %{description: "Revision #{v}. #{current.description || ""}" |> String.slice(0, 2000),
        change_note: Enum.random([nil, "Tightened timings", "Added the P5 alert", "Fixed a typo", "New sounds"])},
      actor: author
    )
  end)
end

# -- Likes and copies --------------------------------------------------------

for preset <- presets, user <- Enum.take_random(users, :rand.uniform(25) - 1) do
  Sharing.like_preset!(preset.id, actor: user)
end

for preset <- presets, n <- 1..(:rand.uniform(40)), :rand.uniform(3) == 1 do
  Sharing.record_copy!(preset.id, "anon:demo-#{preset.id}-#{n}")
end

# -- Comments: a long thread on one preset, 1-5 on about a third of the rest --
#
# The comment rate limit (10 per user per 5 minutes) applies here too, so each
# demo user posts at most 10: 40 of them post 2 in the long thread, and every
# user's remaining budget is spread over the other presets.

comment_bodies = [
  "Works great, thanks!",
  "Does this still work after the latest update?",
  "Added a louder sound for the bomb — much better.",
  "P4 timing is a little early for me, otherwise perfect.",
  "Could you add a version for duo?",
  "The screen flash is a bit much, toned it down to 50% and it's great.",
  "Imported fine, markers line up perfectly 👌",
  "Is there a necro version of this?",
  "Thank you! Got my first enrage kill with this.",
  String.duplicate("Really long feedback about every single phase. ", 15)
]

[busy | rest] = Enum.shuffle(presets)

thread_posters = Enum.take(users, 40)

for {user, i} <- Enum.with_index(thread_posters, 1), round <- 1..2 do
  Sharing.post_comment!(busy.id, "#{Enum.random(comment_bodies)} (##{i * 2 - 2 + round})", actor: user)
end

# Every remaining (user, slot) pair, shuffled, handed out preset by preset.
budget =
  users
  |> Enum.flat_map(fn user -> List.duplicate(user, if(user in thread_posters, do: 8, else: 10)) end)
  |> Enum.shuffle()

{_left, comment_count} =
  rest
  |> Enum.take(div(length(rest), 3))
  |> Enum.reduce({budget, 80}, fn preset, {budget, count} ->
    {posters, budget} = Enum.split(budget, :rand.uniform(5))

    for user <- Enum.uniq(posters),
        do: Sharing.post_comment!(preset.id, Enum.random(comment_bodies), actor: user)

    {budget, count + length(Enum.uniq(posters))}
  end)

IO.puts("Posted #{comment_count} comments.")

# -- Moderation: open reports and a few hidden presets -----------------------

for {preset, user} <- Enum.zip(Enum.take_random(presets, 35), Enum.shuffle(users)) do
  Sharing.report_preset!(preset.id, Enum.random([:spam, :broken, :offensive, :other]), %{note: Enum.random([nil, "Doesn't import for me", "Duplicate of another preset"])}, actor: user)
end

admins = Application.get_env(:runeshare, :admin_emails, [])

case admins do
  [admin_email | _] ->
    admin =
      User
      |> Ash.Query.for_read(:read, %{}, authorize?: false)
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(to_string(&1.email) == admin_email))

    if admin, do: Enum.each(Enum.take_random(presets, 6), &Sharing.hide_preset!(&1, actor: admin))

  [] ->
    :ok
end

IO.puts("""
Demo data loaded: #{user_count} users, #{length(presets)} presets, likes, copies,
versions, comments, reports. Remove it with: mix run priv/repo/demo_data.exs --reset
""")
