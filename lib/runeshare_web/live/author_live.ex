defmodule RuneshareWeb.AuthorLive do
  @moduledoc """
  Public author page: who someone is and everything they have shared that the
  viewer may see (hidden presets only appear to the author and admins).
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.ListComponents
  import RuneshareWeb.PresetComponents

  alias Runeshare.Accounts
  alias Runeshare.Sharing
  alias RuneshareWeb.Paging

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    viewer = socket.assigns.current_user
    # Loads the share/like/copy totals for the stats strip.
    author = Accounts.get_author!(id, actor: viewer)
    author_id = author.id

    socket =
      socket
      |> assign(page_title: author.name, author: author)
      |> assign(
        og: %{
          type: "profile",
          title: "#{author.name} — RuneShare",
          description:
            "RuneScape 3 Watchdog alarms and tile marker presets shared by #{author.name}.",
          url: url(~p"/u/#{author}")
        }
      )
      |> Paging.init(:presets)
      |> Paging.load(:presets, fetch(author_id, viewer))

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_async(:presets, result, socket),
    do: {:noreply, Paging.handle(socket, :presets, result)}

  @impl Phoenix.LiveView
  def handle_event("more_presets", _params, socket) do
    %{author: author, current_user: viewer} = socket.assigns
    {:noreply, Paging.load(socket, :presets, fetch(author.id, viewer))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.breadcrumbs crumbs={[{"Home", ~p"/"}, {@author.name, nil}]} />

      <div class="flex flex-wrap items-center gap-3">
        <.avatar user={@author} class="size-14 text-base" />
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <h1
              id="author-name"
              class="truncate font-display text-xl font-bold tracking-wide uppercase sm:text-2xl"
            >
              {@author.name}
            </h1>
            <span
              :if={@author.role == :admin}
              class="badge rounded-sm font-display badge-sm tracking-wider uppercase badge-primary"
            >
              Admin
            </span>
          </div>
          <p class="text-xs text-base-content/65">
            Member since {Calendar.strftime(@author.inserted_at, "%-d %b %Y")}
          </p>
        </div>
        <.link
          :if={@current_user && @current_user.id == @author.id}
          id="edit-account"
          navigate={~p"/account"}
          class="btn btn-outline btn-sm"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Edit your account
        </.link>
      </div>

      <dl
        id="author-stats"
        class="grid grid-cols-3 divide-x divide-base-content/10 rounded-box border border-base-content/10 bg-base-100"
      >
        <.stat label="Shares" value={@author.share_count} />
        <.stat label="Likes" value={@author.total_likes} />
        <.stat label="Copies" value={@author.total_copies} />
      </dl>

      <.panel id="author-presets" title="Shared presets" icon="hero-share">
        <.async_result assign={@presets}>
          <:loading><.skeleton_rows rows={4} /></:loading>
          <:failed>
            <p class="px-3 py-6 text-center text-sm text-error">Couldn't load these presets.</p>
          </:failed>
          <%!-- Wide content scrolls inside the table, never the page. --%>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead class="bg-base-200 font-display text-[11px] tracking-wider text-base-content/70 uppercase">
                <tr>
                  <th>Title</th>
                  <th class="hidden md:table-cell">Tags</th>
                  <th class="hidden sm:table-cell">Updated</th>
                  <th class="hidden sm:table-cell">Activity</th>
                  <th class="w-0 text-right">Copy</th>
                </tr>
              </thead>
              <tbody id="author-presets-list" phx-update="stream">
                <tr id="author-presets-empty" class="hidden only:table-row">
                  <td colspan="5" class="py-6 text-center text-sm text-base-content/70">
                    Nothing shared yet.
                  </td>
                </tr>
                <tr
                  :for={{dom_id, preset} <- @streams.presets}
                  id={dom_id}
                  class="sm:hover:bg-base-200/60"
                >
                  <td class="w-full max-w-0">
                    <div class="flex items-center gap-2">
                      <span class="badge shrink-0 rounded-sm font-display badge-xs tracking-wider uppercase badge-primary">
                        {kind_short(preset.kind)}
                      </span>
                      <.link
                        navigate={~p"/presets/#{preset}"}
                        class="truncate text-sm font-medium sm:hover:text-primary"
                      >
                        {preset.title}
                      </.link>
                      <span class="shrink-0 font-mono text-[11px] text-base-content/60">
                        v{preset.version}
                      </span>
                      <span
                        :if={preset.hidden}
                        class="badge shrink-0 rounded-sm font-display badge-xs tracking-wider uppercase badge-warning"
                      >
                        Hidden
                      </span>
                    </div>
                    <div class="flex flex-wrap items-center gap-x-2 text-xs text-base-content/65 sm:hidden">
                      <.timestamp at={preset.updated_at} prefix="Updated " />
                      <.counts preset={preset} />
                    </div>
                  </td>
                  <td class="hidden md:table-cell">
                    <span class="flex flex-wrap gap-1">
                      <span
                        :for={tag <- preset.tags}
                        class="badge rounded-sm badge-ghost font-mono badge-xs"
                      >
                        {tag}
                      </span>
                    </span>
                  </td>
                  <td class="hidden whitespace-nowrap text-base-content/70 sm:table-cell">
                    <.timestamp at={preset.updated_at} />
                  </td>
                  <td class="hidden whitespace-nowrap sm:table-cell">
                    <.counts preset={preset} />
                  </td>
                  <td class="text-right">
                    <.copy_button id={"copy-#{preset.id}"} content={preset.content} />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.async_result>
        <.load_more id="more-presets" event="more_presets" paging={@paging.presets} />
      </.panel>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, default: nil

  defp stat(assigns) do
    ~H"""
    <div class="px-3 py-2 text-center">
      <dt class="font-display text-[11px] tracking-wider text-base-content/65 uppercase">
        {@label}
      </dt>
      <dd class="font-mono text-lg font-bold">
        <span :if={@value}>{@value}</span>
        <span :if={!@value} class="text-base-content/60" aria-label="Loading">–</span>
      </dd>
    </div>
    """
  end

  defp fetch(author_id, viewer),
    do: &Sharing.list_presets_by_author!(author_id, actor: viewer, page: &1)
end
