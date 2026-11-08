defmodule RuneshareWeb.Layouts do
  @moduledoc """
  Root and app layouts and theme toggle. Flashes and toasts render through LiveToast.
  """
  use RuneshareWeb, :html

  alias RuneshareWeb.PresetComponents

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc "Meta description of pages that set none of their own."
  @spec default_description() :: String.t()
  def default_description,
    do:
      "Share and copy RuneScape 3 (RS3) Watchdog alarm strings and tile marker presets made by other players."

  @doc """
  Canonical URL of the page being rendered: the page's `og.url` if it set one,
  else the requested URL without its query string.
  """
  @spec canonical_url(map()) :: String.t()
  def canonical_url(assigns),
    do: assigns[:og][:url] || Phoenix.Controller.current_url(assigns.conn, %{})

  @doc """
  Page shell: top navigation, main content, footer and toasts (flashes included).

      <Layouts.app flash={@flash} current_user={@current_user} active={:watchdog_alarm}>
        <h1>Content</h1>
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :any, default: nil, doc: "the signed-in user, if any"
  attr :active, :atom, default: nil, doc: "preset kind whose nav tab is highlighted"
  attr :width, :string, default: "max-w-6xl", doc: "max-width class of the main column"

  attr :connected, :boolean,
    default: true,
    doc: "whether this renders inside a LiveView (every page using this layout does)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar min-h-12 gap-2 border-b border-base-content/10 bg-base-200 px-2 py-0 sm:px-4">
      <div class="navbar-start w-auto flex-1 gap-1">
        <details class="dropdown sm:hidden">
          <summary class="btn btn-square btn-ghost btn-sm" aria-label="Menu">
            <.icon name="hero-bars-3" class="size-5" />
          </summary>
          <ul class="menu dropdown-content z-10 mt-2 w-48 rounded-box border border-base-content/10 bg-base-100 p-1">
            <li :for={kind <- Runeshare.Sharing.preset_kinds()}>
              <.link navigate={PresetComponents.kind_path(kind)}>
                <.icon name={PresetComponents.kind_icon(kind)} class="size-4" />
                {PresetComponents.kind_short(kind)}
              </.link>
            </li>
          </ul>
        </details>
        <.link
          navigate={~p"/"}
          class="flex items-center gap-1.5 font-display text-sm font-bold tracking-[0.12em] uppercase"
        >
          <.icon name="hero-sparkles" class="size-5 text-primary" />
          <span>Rune<span class="text-primary">Share</span></span>
        </.link>
        <nav class="ml-4 hidden h-12 self-stretch font-display text-xs tracking-wider uppercase sm:flex">
          <.link
            :for={kind <- Runeshare.Sharing.preset_kinds()}
            navigate={PresetComponents.kind_path(kind)}
            class={[
              "flex items-center border-b-2 px-3 focus-visible:-outline-offset-2",
              if(@active == kind,
                do: "border-primary text-primary",
                else: "border-transparent sm:hover:border-primary/40 sm:hover:text-primary"
              )
            ]}
          >
            {PresetComponents.kind_short(kind)}
          </.link>
        </nav>
      </div>
      <div class="navbar-end w-auto gap-1">
        <.theme_toggle />
        <%= if @current_user do %>
          <.link
            :if={Runeshare.Accounts.admin?(@current_user)}
            navigate={~p"/moderation"}
            class="btn hidden btn-ghost font-display text-xs tracking-wider uppercase btn-sm md:inline-flex"
          >
            Moderation
          </.link>
          <.link
            navigate={~p"/account"}
            class="btn hidden btn-ghost font-display text-xs tracking-wider uppercase btn-sm md:inline-flex"
          >
            My account
          </.link>
          <details class="dropdown dropdown-end">
            <summary class="btn gap-2 btn-ghost px-1 btn-sm" aria-label="Account menu">
              <PresetComponents.avatar user={@current_user} />
              <span class="hidden text-xs sm:inline">{@current_user.name}</span>
            </summary>
            <ul class="menu dropdown-content z-10 mt-2 w-44 rounded-box border border-base-content/10 bg-base-100 p-1">
              <li>
                <.link navigate={~p"/account"}><.icon name="hero-user-circle" class="size-4" />
                My account</.link>
              </li>
              <li :if={Runeshare.Accounts.admin?(@current_user)}>
                <.link navigate={~p"/moderation"}>
                  <.icon name="hero-flag" class="size-4" /> Moderation
                </.link>
              </li>
              <li>
                <.link href={~p"/sign-out"}>
                  <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Sign out
                </.link>
              </li>
            </ul>
          </details>
        <% else %>
          <.link navigate={~p"/sign-in"} class="btn btn-primary btn-sm">Sign in</.link>
        <% end %>
      </div>
    </header>

    <main class={["mx-auto space-y-4 px-3 py-4 sm:px-4 sm:py-6", @width]}>
      {render_slot(@inner_block)}
    </main>

    <footer class="mx-auto flex max-w-6xl flex-wrap items-center gap-x-1.5 gap-y-3 px-4 pt-2 pb-6 text-[11px] text-base-content/60 sm:gap-y-1">
      <span>RuneShare · community-made, not affiliated with Jagex.</span>
      <span aria-hidden="true">·</span>
      <a
        id="footer-source"
        href="https://github.com/rmand97/runeshare"
        target="_blank"
        rel="noopener noreferrer"
        class="tap inline-flex items-center gap-1 underline-offset-2 sm:hover:text-primary sm:hover:underline"
      >
        <.icon name="hero-code-bracket" class="size-3.5" /> Source on GitHub
      </a>
      <span aria-hidden="true">·</span>
      <a
        id="footer-issues"
        href="https://github.com/rmand97/runeshare/issues/new/choose"
        target="_blank"
        rel="noopener noreferrer"
        class="tap inline-flex items-center gap-1 underline-offset-2 sm:hover:text-primary sm:hover:underline"
      >
        <.icon name="hero-chat-bubble-left-ellipsis" class="size-3.5" /> Report a problem
      </a>
      <span aria-hidden="true">·</span>
      <.link
        id="footer-privacy"
        navigate={~p"/privacy"}
        class="tap underline-offset-2 sm:hover:text-primary sm:hover:underline"
      >
        Privacy
      </.link>
    </footer>

    <LiveToast.toast_group
      flash={@flash}
      connected={@connected}
      toasts_sync={[]}
      corner={:top_right}
      toast_class_fn={&RuneshareWeb.Toasts.toast_class/1}
      connection_notifications={false}
      flash_duration={RuneshareWeb.Toasts.duration()}
    />
    """
  end

  @doc """
  Light/dark toggle. Shows the button that switches to the other theme;
  see <head> in root.html.heex for how the theme is applied.
  """
  def theme_toggle(assigns) do
    ~H"""
    <button
      type="button"
      class="btn btn-square btn-ghost btn-sm in-data-[theme=light]:hidden"
      phx-click={JS.dispatch("phx:set-theme")}
      data-phx-theme="light"
      aria-label="Switch to light theme"
      title="Switch to light theme"
    >
      <.icon name="hero-sun" class="size-5" />
    </button>
    <button
      type="button"
      class="btn btn-square btn-ghost btn-sm in-data-[theme=dark]:hidden"
      phx-click={JS.dispatch("phx:set-theme")}
      data-phx-theme="dark"
      aria-label="Switch to dark theme"
      title="Switch to dark theme"
    >
      <.icon name="hero-moon" class="size-5" />
    </button>
    """
  end
end
