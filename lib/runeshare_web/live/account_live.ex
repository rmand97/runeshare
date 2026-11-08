defmodule RuneshareWeb.AccountLive do
  @moduledoc """
  The signed-in user's private account page: their profile (display name editable,
  email visible only here), everything they have shared and everything they liked.
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.ListComponents
  import RuneshareWeb.PresetComponents

  alias Runeshare.Accounts
  alias Runeshare.Sharing
  alias RuneshareWeb.Paging

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(page_title: "My account")
      |> assign_profile_form(user)
      |> Paging.init(:presets)
      |> Paging.init(:liked)
      |> Paging.load(:presets, fetch(:presets, user))
      |> Paging.load(:liked, fetch(:liked, user))

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_async(list, result, socket) when list in [:presets, :liked],
    do: {:noreply, Paging.handle(socket, list, result)}

  @impl Phoenix.LiveView
  def handle_event("more_presets", _params, socket),
    do: {:noreply, Paging.load(socket, :presets, fetch(:presets, socket.assigns.current_user))}

  def handle_event("more_liked", _params, socket),
    do: {:noreply, Paging.load(socket, :liked, fetch(:liked, socket.assigns.current_user))}

  def handle_event("validate", %{"form" => params}, socket) do
    socket = assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))
    {:noreply, socket}
  end

  # The session cookie still holds this user's token, but it no longer resolves
  # to a user, so the next page load is signed out.
  def handle_event("delete_account", _params, socket) do
    user = socket.assigns.current_user
    Accounts.delete_account!(user, actor: user)

    {:noreply,
     socket
     |> put_flash(:info, "Your account and everything you shared have been deleted")
     |> redirect(to: ~p"/")}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        socket =
          socket
          |> assign(current_user: user)
          |> assign_profile_form(user)
          |> toast(:info, "Display name saved")

        {:noreply, socket}

      {:error, form} ->
        socket = assign(socket, form: form)
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <.breadcrumbs crumbs={[{"Home", ~p"/"}, {"My account", nil}]} />
        <h1 class="font-display text-xl font-bold tracking-wide uppercase sm:text-2xl">
          My account
        </h1>
      </div>

      <div class="grid gap-4 lg:grid-cols-[20rem_1fr] lg:items-start">
        <.panel id="profile" title="Profile" icon="hero-user-circle">
          <div class="flex items-center gap-3 p-3">
            <.avatar user={@current_user} class="size-12 text-sm" />
            <div class="min-w-0">
              <p id="profile-name" class="truncate font-display text-lg font-bold tracking-wide">
                {@current_user.name}
              </p>
              <p class="text-xs text-base-content/65">Your public display name</p>
            </div>
          </div>
          <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 border-t border-base-content/10 px-3 py-2 text-xs">
            <dt class="text-base-content/65">Email</dt>
            <dd class="truncate">
              {@current_user.email}
              <span class="text-base-content/60">· only you see this</span>
            </dd>
            <dt class="text-base-content/65">Member since</dt>
            <dd>{Calendar.strftime(@current_user.inserted_at, "%-d %b %Y")}</dd>
          </dl>
          <.form
            for={@form}
            id="profile-form"
            phx-change="validate"
            phx-submit="save"
            class="border-t border-base-content/10 p-3"
          >
            <.input
              field={@form[:name]}
              label="Display name"
              autocomplete="nickname"
              phx-debounce="300"
              required
            />
            <p class="mb-2 text-xs text-base-content/65">
              Shown next to everything you share. 2–40 characters.
            </p>
            <button
              type="submit"
              class="btn w-full btn-primary btn-sm sm:w-auto"
              phx-disable-with="Saving…"
            >
              Save name
            </button>
          </.form>
        </.panel>

        <.panel id="my-presets" title="Your shares" icon="hero-share">
          <:actions>
            <.link
              :for={kind <- Sharing.preset_kinds()}
              navigate={new_path(kind)}
              class="tap text-xs text-primary sm:hover:underline"
            >
              + {kind_short(kind)}
            </.link>
          </:actions>
          <.async_result assign={@presets}>
            <:loading><.skeleton_rows rows={4} /></:loading>
            <:failed>
              <p class="px-3 py-6 text-center text-sm text-error">Couldn't load your shares.</p>
            </:failed>
            <ul id="my-presets-list" phx-update="stream" class="divide-y divide-base-content/5">
              <li
                id="my-presets-empty"
                class="hidden px-3 py-6 text-center text-sm text-base-content/70 only:block"
              >
                You haven't shared anything yet. Share a
                <.link navigate={new_path(:watchdog_alarm)} class="link link-primary">
                  Watchdog alarm
                </.link>
                or a <.link navigate={new_path(:tile_marker)} class="link link-primary">
                  tile marker preset
                </.link>.
              </li>
              <li
                :for={{dom_id, preset} <- @streams.presets}
                id={dom_id}
                class="flex items-center gap-3 px-3 py-2 sm:hover:bg-base-200/60"
              >
                <span class="badge hidden shrink-0 rounded-sm font-display badge-xs tracking-wider uppercase badge-primary sm:inline-flex">
                  {kind_short(preset.kind)}
                </span>
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2">
                    <.link
                      navigate={~p"/presets/#{preset}"}
                      class="row-link truncate text-sm font-medium sm:hover:text-primary"
                    >
                      {preset.title}
                    </.link>
                    <span class="shrink-0 font-mono text-[11px] text-base-content/60">
                      v{preset.version}
                    </span>
                  </div>
                  <div class="flex flex-wrap items-center gap-x-2 text-xs text-base-content/65">
                    <span class="sm:hidden">{kind_short(preset.kind)} ·</span>
                    <.timestamp at={preset.updated_at} prefix="Updated " />
                    <.counts preset={preset} />
                  </div>
                </div>
                <.link
                  navigate={~p"/presets/#{preset}/edit"}
                  class="btn btn-ghost btn-sm"
                  aria-label={"Edit #{preset.title}"}
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                  <span class="hidden sm:inline">Edit</span>
                </.link>
              </li>
            </ul>
          </.async_result>
          <.load_more id="more-presets" event="more_presets" paging={@paging.presets} />
        </.panel>

        <.panel id="liked-presets" title="Liked" icon="hero-heart" class="lg:col-start-2">
          <.async_result assign={@liked}>
            <:loading><.skeleton_rows rows={3} /></:loading>
            <:failed>
              <p class="px-3 py-6 text-center text-sm text-error">Couldn't load your likes.</p>
            </:failed>
            <ul id="liked-presets-list" phx-update="stream" class="divide-y divide-base-content/5">
              <li
                id="liked-presets-empty"
                class="hidden px-3 py-6 text-center text-sm text-base-content/70 only:block"
              >
                Nothing liked yet. Hit <span class="font-medium">Like</span>
                on a preset to keep it here.
              </li>
              <li
                :for={{dom_id, preset} <- @streams.liked}
                id={dom_id}
                class="flex items-center gap-3 px-3 py-2 sm:hover:bg-base-200/60"
              >
                <span class="badge hidden shrink-0 rounded-sm font-display badge-xs tracking-wider uppercase badge-primary sm:inline-flex">
                  {kind_short(preset.kind)}
                </span>
                <div class="min-w-0 flex-1">
                  <.link
                    navigate={~p"/presets/#{preset}"}
                    class="row-link block truncate text-sm font-medium sm:hover:text-primary"
                  >
                    {preset.title}
                  </.link>
                  <div class="flex flex-wrap items-center gap-x-2 text-xs text-base-content/65">
                    <span class="sm:hidden">{kind_short(preset.kind)} ·</span>
                    <.author_link preset={preset} />
                    <.counts preset={preset} />
                  </div>
                </div>
              </li>
            </ul>
          </.async_result>
          <.load_more id="more-liked" event="more_liked" paging={@paging.liked} />
        </.panel>
      </div>

      <.panel id="delete-account" title="Delete account" icon="hero-trash">
        <div class="flex flex-col gap-3 p-3 text-sm sm:flex-row sm:items-center sm:justify-between">
          <p class="text-base-content/75">
            Deletes your account and everything you shared: presets (with their old versions
            and cover images), comments and likes. This can't be undone. You can sign in again
            later, but you'll start with a new, empty account.
          </p>
          <button
            id="delete-account-button"
            type="button"
            phx-click="delete_account"
            phx-disable-with="Deleting..."
            data-confirm="Delete your account and everything you shared? This can't be undone."
            title="Delete your account and everything you shared"
            class="btn shrink-0 btn-outline btn-error btn-sm"
          >
            <.icon name="hero-trash" class="size-4" /> Delete my account
          </button>
        </div>
      </.panel>
    </Layouts.app>
    """
  end

  defp fetch(:presets, user), do: &Sharing.list_my_presets!(actor: user, page: &1)
  defp fetch(:liked, user), do: &Sharing.list_liked_presets!(actor: user, page: &1)

  defp assign_profile_form(socket, user) do
    form =
      user
      |> Accounts.form_to_update_profile(actor: user)
      |> to_form()

    assign(socket, form: form)
  end
end
