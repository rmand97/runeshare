defmodule RuneshareWeb.Paging do
  @moduledoc """
  "Show more" paging for lists inside a page (your shares, liked presets, an
  author's presets, the moderation queue, comments): the first page loads
  asynchronously into a stream, and each "Show more" appends the next one.

  For a list named `:presets` the LiveView gets:

  - `@presets` — an `AsyncResult` for `<.async_result>` (loading skeleton / error)
  - `@streams.presets` — the loaded rows
  - `@paging.presets` — `%{loaded: n, count: total}`; `remaining/1` gives what's left

  The LiveView supplies a fetch function taking page options
  (`[limit:, offset:, count: true]`) and returning an `Ash.Page.Offset` — a code
  interface call with `page: opts` — and forwards its `handle_async/3` here.

      socket
      |> Paging.init(:presets)
      |> Paging.load(:presets, fn page -> Sharing.list_my_presets!(actor: user, page: page) end)

      def handle_async(:presets, result, socket), do: {:noreply, Paging.handle(socket, :presets, result)}
      def handle_event("more_presets", _params, socket), do: {:noreply, Paging.load(socket, :presets, fetch)}
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [start_async: 3, stream: 4]

  alias Phoenix.LiveView.AsyncResult

  @page_size 20

  @typedoc "Fetches one page: `fn [limit: _, offset: _, count: true] -> %Ash.Page.Offset{} end`."
  @type fetch :: (keyword() -> Ash.Page.Offset.t())

  @doc "Sets up an empty, loading list named `name`."
  @spec init(Phoenix.LiveView.Socket.t(), atom()) :: Phoenix.LiveView.Socket.t()
  def init(socket, name) do
    socket
    |> assign(name, AsyncResult.loading())
    |> put_meta(name, %{loaded: 0, count: 0})
    |> stream(name, [], [])
  end

  @doc "Starts loading the next page of `name` (the first one after `init/2`)."
  @spec load(Phoenix.LiveView.Socket.t(), atom(), fetch()) :: Phoenix.LiveView.Socket.t()
  def load(socket, name, fetch) do
    page = [limit: @page_size, offset: socket.assigns.paging[name].loaded, count: true]
    start_async(socket, name, fn -> fetch.(page) end)
  end

  @doc """
  Handles the `handle_async/3` result for `name`: appends the page to the stream
  (replacing it for the first page). Pass `at: 0` to prepend each page instead,
  which shows a newest-first query oldest-first with older pages added on top.
  """
  @spec handle(
          Phoenix.LiveView.Socket.t(),
          atom(),
          {:ok, Ash.Page.Offset.t()} | {:exit, term()},
          keyword()
        ) ::
          Phoenix.LiveView.Socket.t()
  def handle(socket, name, result, opts \\ [])

  def handle(socket, name, {:ok, %Ash.Page.Offset{} = page}, opts) do
    socket
    |> stream(name, page.results, reset: page.offset == 0, at: Keyword.get(opts, :at, -1))
    |> put_meta(name, %{loaded: page.offset + Enum.count(page.results), count: page.count})
    |> assign(name, AsyncResult.ok(true))
  end

  def handle(socket, name, {:exit, reason}, _opts) do
    assign(socket, name, AsyncResult.failed(socket.assigns[name], {:exit, reason}))
  end

  @doc """
  Adjusts the counts after rows were added (`delta > 0`) or removed (`delta < 0`)
  live, so the next page starts at the right offset.
  """
  @spec shift(Phoenix.LiveView.Socket.t(), atom(), integer()) :: Phoenix.LiveView.Socket.t()
  def shift(socket, name, delta) do
    %{loaded: loaded, count: count} = socket.assigns.paging[name]
    put_meta(socket, name, %{loaded: max(loaded + delta, 0), count: max(count + delta, 0)})
  end

  @doc "How many rows of the list are not loaded yet."
  @spec remaining(%{loaded: non_neg_integer(), count: non_neg_integer()}) :: non_neg_integer()
  def remaining(%{loaded: loaded, count: count}), do: max(count - loaded, 0)

  defp put_meta(socket, name, meta),
    do: assign(socket, :paging, Map.put(socket.assigns[:paging] || %{}, name, meta))
end
