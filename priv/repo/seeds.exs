# From-zero-to-running-system seed. Runs on `mix setup` / `mix ecto.reset`.
# Idempotent: looks things up first and only creates what is missing.

alias Runeshare.Accounts.User
alias Runeshare.Sharing

seed_user = fn email, name ->
  User
  |> Ash.Changeset.for_create(
    :register_with_google,
    %{
      user_info: %{
        "sub" => "seed-" <> email,
        "iss" => "https://accounts.google.com",
        "email" => email,
        "email_verified" => true,
        "name" => name
      },
      oauth_tokens: %{}
    },
    context: %{private: %{ash_authentication?: true}}
  )
  |> Ash.create!()
end

zezima = seed_user.("zezima@example.com", "Zezima")
durial = seed_user.("durial321@example.com", "Durial321")

presets = [
  {zezima, :watchdog_alarm, "Vorago rotation timer",
   "Alarm 10 seconds before each Vorago rotation switch.",
   ~S({"schemaVersion":1,"pluginVersion":"1.0.0","entries":[{"enabled":true,"kind":"alert","name":"Vorago rotation timer","graph":{"version":1,"nodes":[],"connections":[]},"layout":[]}]})},
  {zezima, :watchdog_alarm, "Low prayer warning",
   "Flashes the screen when prayer drops below 20%.",
   ~S({"schemaVersion":1,"pluginVersion":"1.0.0","entries":[{"enabled":true,"kind":"alert","name":"Low prayer warning","graph":{"version":1,"nodes":[],"connections":[]},"layout":[]}]})},
  {durial, :watchdog_alarm, "Telos enrage reminder", nil,
   ~S({"schemaVersion":1,"pluginVersion":"1.0.0","entries":[{"enabled":true,"kind":"alert","name":"Telos enrage reminder","graph":{"version":1,"nodes":[],"connections":[]},"layout":[]}]})},
  {durial, :tile_marker, "Zamorak P4 safe tiles", "Safe spots for phase 4.",
   "TM2ARVaYW1vcmFrIFA0IHNhZmUgdGlsZXMAAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYn"},
  {zezima, :tile_marker, "Raksha shadow tiles", nil,
   "TM2ARNSYWtzaGEgc2hhZG93IHRpbGVzAAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJw"}
]

existing =
  MapSet.new(
    Sharing.list_presets!(:watchdog_alarm) ++ Sharing.list_presets!(:tile_marker),
    & &1.title
  )

tags = %{
  "Vorago rotation timer" => ["vorago", "boss"],
  "Low prayer warning" => ["prayer"],
  "Telos enrage reminder" => ["telos", "boss"],
  "Zamorak P4 safe tiles" => ["zamorak", "boss"],
  "Raksha shadow tiles" => ["raksha", "boss"]
}

for {author, kind, title, description, content} <- presets, title not in existing do
  Sharing.share_preset!(
    %{kind: kind, title: title, description: description, content: content, tags: tags[title]},
    actor: author
  )
end

# A cover image on a tile marker preset (dev stores it under priv/storage).
[tiles | _rest] = Sharing.list_presets!(:tile_marker, %{search: "Zamorak P4"})

if is_nil(tiles.cover_image_url) do
  image = Path.join(__DIR__, "seed_images/cover.png")

  Sharing.edit_preset!(
    tiles,
    %{cover_image: %Plug.Upload{path: image, filename: "cover.png", content_type: "image/png"}},
    actor: tiles.author
  )
end

# Engagement: a second version, a like and a comment on the first Watchdog preset.
[first | _rest] = Sharing.list_presets!(:watchdog_alarm)
first = Sharing.get_preset!(first.id, actor: first.author)

if first.version == 1 do
  Sharing.edit_preset!(
    first,
    %{
      description: (first.description || "") <> " Updated timings.",
      change_note: "Tightened the enrage timings"
    },
    actor: first.author
  )
end

# Copies are counted once per visitor, so re-running the seeds changes nothing.
for n <- 1..3, do: Sharing.record_copy!(first.id, "anon:seed-#{n}")

fan = if first.author_id == zezima.id, do: durial, else: zezima
Sharing.like_preset!(first.id, actor: fan)

if Sharing.list_comments!(first.id) == [] do
  Sharing.post_comment!(first.id, "Works perfectly, thanks!", actor: fan)
end

# Moderation: dev admins come from ADMIN_EMAILS in .env (e.g. ADMIN_EMAILS=you@gmail.com).

# Imported presets, as prod syncs them at boot: the RuneScape Wiki's tile markers
# (Guide:Tilemarkers), the saved r/runescape Watchdog alarms and, when DISCORD_BOT_TOKEN and WATCHDOG_DISCORD_CHANNEL_ID
# are set, the Watchdog Discord's alarms. Needs network; logs a warning and moves
# on without it.
wiki_author = "raflnatorr@gmail.com"

with {:error, _not_found} <- Runeshare.Accounts.get_user_by_email(wiki_author),
     do: seed_user.(wiki_author, "Rolf")

Runeshare.Sharing.WikiTileMarkers.sync_as(wiki_author)
Runeshare.Sharing.RedditWatchdogAlarms.sync_as(wiki_author)

if Application.get_env(:runeshare, :watchdog_discord, [])[:channel_id] &&
     Runeshare.Discord.configured?(),
   do: Runeshare.Sharing.DiscordWatchdogAlarms.sync_as(wiki_author)
