# Branding

Assets for listings outside the site, such as the sign-in provider apps.

- `app-icon.svg` / `app-icon-1024.png`: square app icon (gold sparkles on
  charcoal, the same mark as `priv/static/favicon.svg` without rounded corners,
  since Discord and others crop icons themselves). Used for the Discord
  application icon and the GitHub OAuth app logo.

## OAuth app description

Short (GitHub, Twitch):

> RuneShare is a community site for RuneScape 3 players to share and copy plugin import strings: Watchdog alarm setups and tile marker presets. Sign in to share your own, like and comment on others'.

Longer (Discord, max 400 characters):

> RuneShare is a community site for RuneScape 3 players. Share your Watchdog alarm strings and tile marker presets, and copy setups other players made for bosses, slayer and skilling. We only use your Discord account to sign you in: your username and avatar show next to what you share, and your email is never shown publicly.

Homepage URL: `https://runeshare.dk`. Callback URLs: `https://runeshare.dk/auth/user/<google|github|discord|twitch>/callback`.
