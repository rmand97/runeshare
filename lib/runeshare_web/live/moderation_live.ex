defmodule RuneshareWeb.ModerationLive do
  @moduledoc """
  Admin-only queue of open reports, oldest first. Each report can be dismissed,
  or acted on by hiding, unhiding or deleting the reported preset.
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.ListComponents
  import RuneshareWeb.PresetComponents

  alias Runeshare.Sharing
  alias RuneshareWeb.Paging

  @impl Phoenix.LiveView
  def mount(_params, _session, %{assigns: %{current_user: %{role: :admin} = admin}} = socket) do
    socket =
      socket
      |> assign(page_title: "Moderation", report_index: %{})
      |> Paging.init(:reports)
      |> Paging.load(:reports, fetch(admin))

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> put_flash(:error, "Only moderators can open the moderation queue.")
      |> redirect(to: ~p"/")

    {:ok, socket}
  end

  # The buttons act on loaded report structs, kept in `report_index` by id.
  @impl Phoenix.LiveView
  def handle_async(:reports, {:ok, page} = result, socket) do
    socket =
      socket
      |> Paging.handle(:reports, result)
      |> assign(
        report_index: Map.merge(socket.assigns.report_index, Map.new(page.results, &{&1.id, &1}))
      )

    {:noreply, socket}
  end

  def handle_async(:reports, result, socket),
    do: {:noreply, Paging.handle(socket, :reports, result)}

  @impl Phoenix.LiveView
  def handle_event("more_reports", _params, socket),
    do: {:noreply, Paging.load(socket, :reports, fetch(socket.assigns.current_user))}

  def handle_event(action, %{"id" => id}, socket)
      when action in ["resolve", "hide", "unhide", "delete"] do
    admin = socket.assigns.current_user

    socket =
      case Map.fetch(socket.assigns.report_index, id) do
        {:ok, report} -> moderate(socket, action, report, admin)
        :error -> socket
      end

    {:noreply, socket}
  end

  defp moderate(socket, "resolve", report, admin) do
    Sharing.resolve_report!(report, actor: admin)

    socket
    |> drop_reports([report])
    |> toast(:info, "Report dismissed")
  end

  defp moderate(socket, "hide", report, admin) do
    Sharing.hide_preset!(report.preset, actor: admin)
    Sharing.resolve_report!(report, actor: admin)

    socket
    |> drop_reports([report])
    |> mark_hidden(report.preset_id, true)
    |> toast(:info, "Preset hidden and report resolved")
  end

  defp moderate(socket, "unhide", report, admin) do
    Sharing.unhide_preset!(report.preset, actor: admin)

    socket
    |> mark_hidden(report.preset_id, false)
    |> toast(:info, "Preset visible again")
  end

  # Deleting the preset cascades to all of its reports.
  defp moderate(socket, "delete", report, admin) do
    Sharing.delete_preset!(report.preset, actor: admin)

    socket
    |> drop_reports(reports_for(socket, report.preset_id))
    |> toast(:info, "Preset deleted")
  end

  defp drop_reports(socket, reports) do
    socket = Enum.reduce(reports, socket, &stream_delete(&2, :reports, &1))
    socket = Paging.shift(socket, :reports, -Enum.count(reports))
    ids = Enum.map(reports, & &1.id)
    assign(socket, report_index: Map.drop(socket.assigns.report_index, ids))
  end

  defp mark_hidden(socket, preset_id, hidden) do
    updated =
      socket
      |> reports_for(preset_id)
      |> Enum.map(&%{&1 | preset: %{&1.preset | hidden: hidden}})

    socket = Enum.reduce(updated, socket, &stream_insert(&2, :reports, &1))

    assign(socket,
      report_index: Map.merge(socket.assigns.report_index, Map.new(updated, &{&1.id, &1}))
    )
  end

  defp fetch(admin), do: &Sharing.list_open_reports!(actor: admin, page: &1)

  defp reports_for(socket, preset_id) do
    socket.assigns.report_index
    |> Map.values()
    |> Enum.filter(&(&1.preset_id == preset_id))
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <.breadcrumbs crumbs={[{"Home", ~p"/"}, {"Moderation", nil}]} />
        <h1 class="font-display text-xl font-bold tracking-wide uppercase sm:text-2xl">
          Moderation
        </h1>
      </div>

      <.panel id="reports" title="Open reports" icon="hero-flag">
        <.async_result assign={@reports}>
          <:loading><.skeleton_rows rows={4} /></:loading>
          <:failed>
            <p class="px-3 py-6 text-center text-sm text-error">Couldn't load the queue.</p>
          </:failed>
          <ul id="reports-list" phx-update="stream" class="divide-y divide-base-content/5">
            <li
              id="reports-empty"
              class="hidden px-3 py-6 text-center text-sm text-base-content/70 only:block"
            >
              No open reports. The queue is clear.
            </li>
            <li
              :for={{dom_id, report} <- @streams.reports}
              id={dom_id}
              class="flex flex-col gap-2 p-3 sm:flex-row sm:items-start sm:gap-4 sm:hover:bg-base-200/60"
            >
              <div class="min-w-0 flex-1 space-y-1">
                <div class="flex flex-wrap items-center gap-2">
                  <span class={[
                    "badge rounded-sm font-display badge-sm tracking-wider uppercase",
                    reason_class(report.reason)
                  ]}>
                    {reason_label(report.reason)}
                  </span>
                  <span class="badge rounded-sm font-display badge-xs tracking-wider uppercase badge-primary">
                    {kind_short(report.preset.kind)}
                  </span>
                  <.link
                    navigate={~p"/presets/#{report.preset}"}
                    class="truncate text-sm font-medium sm:hover:text-primary"
                  >
                    {report.preset.title}
                  </.link>
                  <span
                    :if={report.preset.hidden}
                    class="badge rounded-sm font-display badge-xs tracking-wider uppercase badge-warning"
                  >
                    Hidden
                  </span>
                </div>
                <p :if={report.note} class="text-sm text-base-content/80">{report.note}</p>
                <p class="flex flex-wrap items-center gap-x-2 text-xs text-base-content/65">
                  <span>
                    By
                    <.link
                      navigate={~p"/u/#{report.preset.author}"}
                      class="text-base-content/70 sm:hover:text-primary"
                    >
                      {author_name(report.preset)}
                    </.link>
                  </span>
                  <span>
                    · reported by
                    <.link
                      navigate={~p"/u/#{report.reporter}"}
                      class="text-base-content/70 sm:hover:text-primary"
                    >
                      {report.reporter.name}
                    </.link>
                  </span>
                  <.timestamp at={report.inserted_at} />
                </p>
              </div>
              <div class="flex flex-wrap gap-1 sm:shrink-0 sm:justify-end">
                <button
                  type="button"
                  class="btn btn-ghost btn-sm"
                  phx-click="resolve"
                  phx-value-id={report.id}
                >
                  <.icon name="hero-check" class="size-4" /> Resolve
                </button>
                <button
                  :if={!report.preset.hidden}
                  type="button"
                  class="btn btn-outline btn-sm btn-warning"
                  phx-click="hide"
                  phx-value-id={report.id}
                >
                  <.icon name="hero-eye-slash" class="size-4" /> Hide preset
                </button>
                <button
                  :if={report.preset.hidden}
                  type="button"
                  class="btn btn-outline btn-sm"
                  phx-click="unhide"
                  phx-value-id={report.id}
                >
                  <.icon name="hero-eye" class="size-4" /> Unhide
                </button>
                <button
                  type="button"
                  class="btn btn-outline btn-error btn-sm"
                  phx-click="delete"
                  phx-value-id={report.id}
                  data-confirm={"Delete \"#{report.preset.title}\" for good?"}
                >
                  <.icon name="hero-trash" class="size-4" /> Delete preset
                </button>
              </div>
            </li>
          </ul>
        </.async_result>
        <.load_more id="more-reports" event="more_reports" paging={@paging.reports} />
      </.panel>
    </Layouts.app>
    """
  end

  defp reason_label(:spam), do: "Spam"
  defp reason_label(:broken), do: "Broken"
  defp reason_label(:offensive), do: "Offensive"
  defp reason_label(:other), do: "Other"

  defp reason_class(:offensive), do: "badge-error"
  defp reason_class(_reason), do: "badge-warning badge-outline"
end
