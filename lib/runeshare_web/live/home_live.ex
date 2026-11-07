defmodule RuneshareWeb.HomeLive do
  @moduledoc """
  Landing page: what the site is for, share counts, and the newest shares of each kind.
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.PresetComponents

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.Socket.Broadcast
  alias Runeshare.Sharing

  @newest 5
  # The client enforces a stream's `limit` over all children of the list, and the
  # list also holds its "Nothing shared yet" placeholder: one extra slot for that.
  @stream_limit @newest + 1

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    kinds = Sharing.preset_kinds()

    if connected?(socket) do
      Enum.each(kinds, &Sharing.subscribe_to_kind/1)
    end

    # Each kind's newest shares stream under the kind's own name (`@streams.tile_marker`).
    socket =
      Enum.reduce(
        kinds,
        assign(socket, page_title: "RS3 Watchdog alarms & tile markers", copied: MapSet.new()),
        fn kind, socket ->
          stream_async(socket, kind, fn ->
            {:ok, Sharing.list_presets!(kind, page: [limit: @newest]).results,
             limit: @stream_limit}
          end)
        end
      )

    {:ok, reload_stats(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("copied", %{"id" => id}, socket) do
    {:noreply, track_copy(socket, id, & &1.kind)}
  end

  @impl Phoenix.LiveView
  def handle_info(%Broadcast{event: event, payload: %{data: %{id: id}}}, socket)
      when event in ["share", "unhide"] do
    # The preset may already be gone (or invisible to us) by the time we re-fetch it.
    case Sharing.get_preset(id) do
      {:ok, preset} ->
        socket =
          socket
          |> stream_insert(preset.kind, preset, at: 0, limit: @stream_limit)
          |> reload_stats()

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_info(%Broadcast{event: event, payload: %{data: preset}}, socket)
      when event in ["destroy", "hide"] do
    socket =
      socket
      |> stream_delete(preset.kind, preset)
      |> reload_stats()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="rounded-box border border-base-content/10 bg-base-100">
        <div class="grid gap-4 p-4 sm:p-5 md:grid-cols-[1fr_auto] md:items-end">
          <div>
            <p class="font-display text-[11px] tracking-[0.2em] text-primary uppercase">
              RS3 plugin config exchange
            </p>
            <h1 class="mt-1 font-display text-2xl font-bold tracking-wide uppercase sm:text-3xl">
              Alarms &amp; tile markers, ready to paste.
            </h1>
            <p class="mt-2 max-w-xl text-sm text-base-content/70">
              Share your Watchdog alarm strings and tile marker presets. Find a set for your
              boss, hit copy, import it in the plugin.
            </p>
          </div>
          <div class="flex gap-2">
            <.link
              navigate={new_path(:watchdog_alarm)}
              class="btn flex-1 btn-primary btn-sm md:flex-none"
            >
              <.icon name="hero-plus" class="size-4" /> Share one
            </.link>
            <.link
              navigate={kind_path(:watchdog_alarm)}
              class="btn flex-1 btn-outline btn-sm md:flex-none"
            >
              Browse all
            </.link>
          </div>
        </div>
        <.async_result :let={stats} assign={@stats}>
          <:loading>
            <div class="grid grid-cols-3 divide-x divide-base-content/10 border-t border-base-content/10">
              <div :for={_stat <- 1..3} class="space-y-1.5 px-4 py-2.5">
                <div class="mx-auto h-4 w-8 skeleton"></div>
                <div class="mx-auto h-2.5 w-14 skeleton"></div>
              </div>
            </div>
          </:loading>
          <:failed></:failed>
          <div
            id="stats"
            class="grid grid-cols-3 divide-x divide-base-content/10 border-t border-base-content/10 text-center"
          >
            <.stat
              :for={{kind, count} <- stats.counts}
              id={"stat-#{kind}"}
              value={count}
              label={kind_short(kind)}
            />
            <.stat
              id="stat-last-share"
              value={if stats.last_shared, do: time_ago(stats.last_shared), else: "—"}
              label="last share"
            />
          </div>
        </.async_result>
      </div>

      <div class="grid gap-4 md:grid-cols-2">
        <.newest_panel
          kind={:watchdog_alarm}
          result={@watchdog_alarm}
          presets={@streams.watchdog_alarm}
        />
        <.newest_panel kind={:tile_marker} result={@tile_marker} presets={@streams.tile_marker} />
      </div>
    </Layouts.app>
    """
  end

  attr :kind, :atom, required: true
  attr :result, AsyncResult, required: true
  attr :presets, :any, required: true, doc: "the kind's stream"

  defp newest_panel(assigns) do
    ~H"""
    <.panel id={"newest-#{@kind}"} title={"Newest #{kind_short(@kind)}"} icon={kind_icon(@kind)}>
      <:actions>
        <.link navigate={kind_path(@kind)} class="text-xs text-primary sm:hover:underline">
          View all
        </.link>
      </:actions>
      <.async_result assign={@result}>
        <:loading><.skeleton_rows rows={5} /></:loading>
        <:failed>
          <p class="px-3 py-4 text-sm text-error">Couldn't load presets.</p>
        </:failed>
        <ul id={"newest-#{@kind}-list"} phx-update="stream" class="divide-y divide-base-content/5">
          <li
            id={"newest-#{@kind}-empty"}
            class="hidden px-3 py-4 text-sm text-base-content/70 only:block"
          >
            Nothing shared yet.
            <.link navigate={new_path(@kind)} class="link link-primary">Be the first.</.link>
          </li>
          <li
            :for={{dom_id, preset} <- @presets}
            id={dom_id}
            class="flex items-center gap-3 px-3 py-2 sm:hover:bg-base-200/60"
          >
            <div class="min-w-0 flex-1">
              <.link
                navigate={~p"/presets/#{preset}"}
                class="block truncate text-sm font-medium sm:hover:text-primary"
              >
                {preset.title}
              </.link>
              <div class="flex flex-wrap items-center gap-x-1.5 text-xs text-base-content/65">
                <.author_link preset={preset} /> · <.timestamp at={preset.inserted_at} />
                <.counts preset={preset} />
              </div>
              <.tag_badges
                tags={preset.tags}
                path={&"#{kind_path(@kind)}?#{URI.encode_query(tag: &1)}"}
                patch={false}
                class="mt-0.5"
              />
            </div>
            <.copy_button id={"copy-#{preset.id}"} content={preset.content} track={preset.id} />
          </li>
        </ul>
      </.async_result>
    </.panel>
    """
  end

  attr :id, :string, required: true
  attr :value, :any, required: true
  attr :label, :string, required: true

  defp stat(assigns) do
    ~H"""
    <div id={@id} class="py-2">
      <div class="font-mono text-sm text-primary sm:text-base">{@value}</div>
      <div class="text-[10px] tracking-wider text-base-content/65 uppercase">{@label}</div>
    </div>
    """
  end

  # Recounted from the database rather than adjusted per broadcast: increments and
  # decrements drift (missed or foreign messages), a recount can't. The previous
  # numbers stay on screen while it runs.
  defp reload_stats(socket),
    do: assign_async(socket, :stats, fn -> {:ok, %{stats: Sharing.preset_stats!()}} end)
end
