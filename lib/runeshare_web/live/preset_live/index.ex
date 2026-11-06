defmodule RuneshareWeb.PresetLive.Index do
  @moduledoc """
  Searchable, sortable, paginated listing of one preset kind. The kind comes from the
  live action. Pages load asynchronously; the first page of the newest-first listing
  picks up new and deleted presets live.
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.PresetComponents

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.Socket.Broadcast
  alias Runeshare.Sharing
  alias Runeshare.Sharing.Preset.Changes.NormalizeTags

  @page_size 24

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    kind = socket.assigns.live_action

    if connected?(socket) do
      RuneshareWeb.Endpoint.subscribe("presets:shared:#{kind}")
      RuneshareWeb.Endpoint.subscribe("presets:deleted:#{kind}")
    end

    socket =
      socket
      |> assign(kind: kind, page_title: kind_heading(kind), page_size: @page_size)
      |> assign(page: AsyncResult.loading(), copied: MapSet.new())
      |> stream(:presets, [])

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    search = params |> Map.get("q", "") |> String.trim()
    offset = params |> Map.get("offset", "0") |> parse_offset()
    sort = parse_sort(params["sort"])
    kind = socket.assigns.kind
    # `?tag=Zammy` finds presets tagged "zamorak", the same way saving normalises tags.
    tag = params |> Map.get("tag", "") |> List.wrap() |> NormalizeTags.normalize() |> Enum.join()

    socket =
      socket
      |> assign(search: search, sort: sort, offset: offset, tag: tag)
      |> assign(filters: %{kind: kind, q: search, sort: sort, tag: tag, offset: offset})
      |> load_page()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_async(:page, {:ok, page}, socket) do
    meta = %{
      count: page.count,
      offset: page.offset,
      shown: Enum.count(page.results),
      more?: page.more?
    }

    socket =
      socket
      |> stream(:presets, page.results, reset: true)
      |> assign(page: AsyncResult.ok(socket.assigns.page, meta))

    {:noreply, socket}
  end

  def handle_async(:page, {:exit, reason}, socket) do
    socket = assign(socket, page: AsyncResult.failed(socket.assigns.page, {:exit, reason}))
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"q" => search}, socket) do
    path = list_path(socket.assigns.filters, q: search, offset: 0)
    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("copied", %{"id" => id}, socket) do
    {:noreply, track_copy(socket, id)}
  end

  # A preset of this kind was shared or deleted somewhere: reload the current page.
  # Re-querying keeps order, pagination and totals exact; the rows on screen stay
  # until the new page arrives.
  @impl Phoenix.LiveView
  def handle_info(%Broadcast{event: event}, socket)
      when event in ["share", "destroy", "hide", "unhide"] do
    {:noreply, load_page(socket)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active={@kind}>
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <.breadcrumbs crumbs={[{"Home", ~p"/"}, {kind_short(@kind), nil}]} />
          <h1 class="font-display text-xl font-bold tracking-wide uppercase sm:text-2xl">
            {kind_heading(@kind)}
            <span
              :if={@page.ok?}
              class="align-middle font-mono text-sm font-normal text-base-content/60"
            >
              {@page.result.count}
            </span>
          </h1>
        </div>
        <.link navigate={new_path(@kind)} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> Share
        </.link>
      </div>

      <div class="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
        <form id="search-form" phx-change="search" role="search" class="w-full sm:max-w-sm">
          <label class="input w-full input-sm">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <span class="sr-only">Search by title</span>
            <input
              id="search-q"
              type="search"
              name="q"
              value={@search}
              placeholder="Search by title"
              aria-label="Search by title"
              phx-debounce="300"
              class="grow"
            />
          </label>
        </form>
        <div class="flex flex-wrap gap-2">
          <div class="join">
            <.link
              :for={kind <- Sharing.Preset.kinds()}
              navigate={kind_path(kind)}
              class={["btn join-item btn-sm", kind == @kind && "btn-primary"]}
            >
              {kind_short(kind)}
            </.link>
          </div>
          <nav class="join" aria-label="Sort">
            <.link
              :for={
                {sort, label} <- [
                  newest: "Newest",
                  most_liked: "Most liked",
                  most_copied: "Most copied"
                ]
              }
              id={"sort-#{sort}"}
              patch={list_path(@filters, sort: sort, offset: 0)}
              aria-current={if sort == @sort, do: "true"}
              class={["btn join-item btn-sm", if(sort == @sort, do: "btn-primary", else: "btn-ghost")]}
            >
              {label}
            </.link>
          </nav>
        </div>
      </div>

      <div :if={@tag != ""} id="active-tag" class="flex items-center gap-2 text-sm">
        <span class="text-base-content/70">Tagged</span>
        <span class="badge gap-1 rounded-sm font-display badge-sm tracking-wider uppercase badge-primary">
          {@tag}
          <.link
            patch={list_path(@filters, tag: "", offset: 0)}
            aria-label={"Clear tag #{@tag}"}
            class="inline-flex"
          >
            <.icon name="hero-x-mark" class="size-3.5" />
          </.link>
        </span>
      </div>

      <%!-- Wide content scrolls inside the table, never the page. --%>
      <div class="overflow-x-auto rounded-box border border-base-content/10 bg-base-100">
        <.async_result :let={_meta} assign={@page}>
          <:loading><.skeleton_rows rows={6} /></:loading>
          <:failed>
            <p class="px-3 py-6 text-center text-sm text-error">Couldn't load presets.</p>
          </:failed>
          <table
            id="presets"
            class={["table table-sm transition-opacity", @page.loading && "opacity-60"]}
          >
            <thead class="bg-base-200 font-display text-[11px] tracking-wider text-base-content/70 uppercase">
              <tr>
                <th>Title</th>
                <th class="hidden md:table-cell">Author</th>
                <th class="hidden sm:table-cell">Updated</th>
                <th class="hidden sm:table-cell">Activity</th>
                <th class="hidden xl:table-cell">String</th>
                <th class="w-0 text-right">Copy</th>
              </tr>
            </thead>
            <tbody id="presets-body" phx-update="stream">
              <tr id="presets-empty" class="hidden only:table-row">
                <td colspan="6" class="py-6 text-center text-sm text-base-content/70">
                  No presets found.
                </td>
              </tr>
              <tr
                :for={{dom_id, preset} <- @streams.presets}
                id={dom_id}
                class="sm:hover:bg-base-200/60"
              >
                <td class="w-full max-w-0">
                  <div class="flex items-start gap-3">
                    <img
                      :if={preset.cover_image_url}
                      src={preset.cover_image_url}
                      alt=""
                      loading="lazy"
                      class="mt-0.5 h-10 w-16 shrink-0 rounded-sm border border-base-content/10 bg-base-200 object-cover"
                    />
                    <div class="min-w-0 flex-1">
                      <div class="flex items-center gap-2">
                        <.link
                          navigate={~p"/presets/#{preset}"}
                          class="truncate font-medium sm:hover:text-primary"
                        >
                          {preset.title}
                        </.link>
                        <span class="shrink-0 font-mono text-[11px] text-base-content/60">
                          v{preset.version}
                        </span>
                      </div>
                      <div
                        :if={preset.description}
                        class="truncate text-xs text-base-content/65 max-sm:hidden"
                      >
                        {preset.description}
                      </div>
                      <.tag_badges tags={preset.tags} path={&list_path(@filters, tag: &1, offset: 0)} />
                      <div class="flex flex-wrap items-center gap-x-2 text-xs text-base-content/65 sm:hidden">
                        <%!-- Long display names (up to 40 chars) truncate instead of wrapping. --%>
                        <span class="flex max-w-full min-w-0 items-center gap-1">
                          <span class="min-w-0 truncate">
                            <.author_link preset={preset} avatar={false} />
                          </span>
                          <span class="shrink-0">· {time_ago(preset.updated_at)}</span>
                        </span>
                        <.counts preset={preset} />
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden whitespace-nowrap md:table-cell">
                  <.author_link preset={preset} />
                </td>
                <td class="hidden whitespace-nowrap text-base-content/70 sm:table-cell">
                  <.timestamp at={preset.updated_at} />
                </td>
                <td class="hidden whitespace-nowrap sm:table-cell">
                  <.counts preset={preset} />
                </td>
                <td class="hidden max-w-32 truncate font-mono text-[11px] text-base-content/60 xl:table-cell">
                  {preset.content}
                </td>
                <td class="text-right">
                  <.copy_button id={"copy-#{preset.id}"} content={preset.content} track={preset.id} />
                </td>
              </tr>
            </tbody>
          </table>
        </.async_result>
      </div>

      <.pagination
        :if={@page.ok? and @page.result.count > @page_size}
        meta={@page.result}
        filters={@filters}
        page_size={@page_size}
      />
    </Layouts.app>
    """
  end

  attr :meta, :map, required: true
  attr :filters, :map, required: true, doc: "current `kind`, `q`, `sort`, `tag` and `offset`"
  attr :page_size, :integer, required: true

  defp pagination(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2 text-xs">
      <span class="hidden text-base-content/65 sm:inline">
        Showing {@meta.offset + 1}–{@meta.offset + @meta.shown} of {@meta.count}
      </span>
      <nav class="join mx-auto sm:mx-0" aria-label="Pagination">
        <.link
          patch={list_path(@filters, offset: max(@meta.offset - @page_size, 0))}
          class={["btn join-item btn-sm", @meta.offset == 0 && "btn-disabled"]}
        >
          <.icon name="hero-chevron-left" class="size-4" /> Prev
        </.link>
        <span class="btn pointer-events-none join-item font-mono btn-sm">
          {div(@meta.offset, @page_size) + 1} / {div(@meta.count - 1, @page_size) + 1}
        </span>
        <.link
          patch={list_path(@filters, offset: @meta.offset + @page_size)}
          class={["btn join-item btn-sm", !@meta.more? && "btn-disabled"]}
        >
          Next <.icon name="hero-chevron-right" class="size-4" />
        </.link>
      </nav>
    </div>
    """
  end

  # Live inserts/deletes only make sense where newest-first order holds.
  defp load_page(socket) do
    %{kind: kind, search: search, sort: sort, offset: offset, tag: tag} = socket.assigns
    filters = %{search: blank_to_nil(search), sort: sort, tag: blank_to_nil(tag)}

    socket
    |> assign(page: AsyncResult.loading(socket.assigns.page))
    |> start_async(:page, fn ->
      Sharing.list_presets!(kind, filters, page: [limit: @page_size, offset: offset, count: true])
    end)
  end

  # The listing URL for the current `filters`, with `changes` applied.
  defp list_path(%{kind: kind} = filters, changes) do
    params =
      filters
      |> Map.delete(:kind)
      |> Map.merge(Map.new(changes))
      |> Map.reject(fn {_key, value} -> value in ["", 0, :newest] end)

    kind_path(kind) <> if(params == %{}, do: "", else: "?" <> URI.encode_query(params))
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp parse_sort("most_liked"), do: :most_liked
  defp parse_sort("most_copied"), do: :most_copied
  defp parse_sort(_sort), do: :newest

  defp parse_offset(raw) do
    case Integer.parse(raw) do
      {offset, ""} when offset >= 0 -> offset
      _invalid -> 0
    end
  end
end
