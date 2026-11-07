defmodule RuneshareWeb.Router do
  use RuneshareWeb, :router
  use AshAuthentication.Phoenix.Router

  # Test-only: lets LiveViews join the Ecto sandbox of the browser test that drives them.
  # Prepended so it runs before AshAuthentication loads the signed-in user.
  @sandbox_mounts if Application.compile_env(:runeshare, :sql_sandbox),
                    do: [{RuneshareWeb.LiveSandbox, :default}],
                    else: []

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RuneshareWeb.Plugs.VisitorId
    plug :fetch_live_flash
    plug :put_root_layout, html: {RuneshareWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RuneshareWeb.Plugs.ContentSecurityPolicy
    plug :load_from_session
    plug RuneshareWeb.Plugs.LogMetadata
  end

  # Crawler files: no session, no CSRF, served at the site root.
  scope "/", RuneshareWeb do
    get "/robots.txt", SeoController, :robots
    get "/sitemap.xml", SeoController, :sitemap
  end

  scope "/", RuneshareWeb do
    pipe_through :browser

    ash_authentication_live_session :public,
      on_mount_prepend: @sandbox_mounts,
      on_mount: {RuneshareWeb.LiveUserAuth, :live_user_optional} do
      live "/", HomeLive, :index
      live "/watchdog", PresetLive.Index, :watchdog_alarm
      live "/tile-markers", PresetLive.Index, :tile_marker
      live "/presets/:id", PresetLive.Show, :show
      live "/presets/:id/v/:number", PresetLive.Show, :version
      live "/u/:id", AuthorLive, :show
      live "/privacy", PrivacyLive, :show
    end

    ash_authentication_live_session :authenticated,
      on_mount_prepend: @sandbox_mounts,
      on_mount: {RuneshareWeb.LiveUserAuth, :live_user_required} do
      live "/watchdog/new", PresetLive.Form, :watchdog_alarm
      live "/tile-markers/new", PresetLive.Form, :tile_marker
      live "/presets/:id/edit", PresetLive.Form, :edit
      live "/account", AccountLive, :index
      live "/moderation", ModerationLive, :index
    end

    auth_routes AuthController, Runeshare.Accounts.User, path: "/auth"
    sign_out_route AuthController, "/sign-out"

    sign_in_route auth_routes_prefix: "/auth",
                  gettext_fn: {RuneshareWeb.AuthText, :translate},
                  on_mount:
                    List.flatten([@sandbox_mounts, {RuneshareWeb.LiveUserAuth, :live_no_user}]),
                  overrides: [
                    RuneshareWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]
  end

  # Enable LiveDashboard and AshAdmin in development
  if Application.compile_env(:runeshare, :dev_routes) do
    import AshAdmin.Router
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: RuneshareWeb.Telemetry,
        csp_nonce_assign_key: %{img: :csp_nonce, style: :csp_nonce, script: :csp_nonce}
    end

    # Cover images stored by AshStorage.Service.Disk; prod serves them from Tigris.
    forward "/storage", AshStorage.Plug.DiskServe, root: "priv/storage"

    scope "/admin" do
      pipe_through :browser

      ash_admin "/", csp_nonce_assign_key: :csp_nonce
    end
  end
end
