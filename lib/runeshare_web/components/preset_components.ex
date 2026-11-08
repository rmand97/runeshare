defmodule RuneshareWeb.PresetComponents do
  @moduledoc """
  Ledger-style building blocks shared by every page that shows presets: per-kind
  labels and paths, panels, avatars, the copy button and relative timestamps.
  """

  use RuneshareWeb, :html

  @doc "Human name of a preset kind."
  @spec kind_label(atom()) :: String.t()
  def kind_label(:watchdog_alarm), do: "Watchdog alarm"
  def kind_label(:tile_marker), do: "Tile marker preset"

  @doc "Short badge/nav name of a preset kind."
  @spec kind_short(atom()) :: String.t()
  def kind_short(:watchdog_alarm), do: "Watchdog"
  def kind_short(:tile_marker), do: "Tile markers"

  @doc "Plural heading for a preset kind's listing page."
  @spec kind_heading(atom()) :: String.t()
  def kind_heading(:watchdog_alarm), do: "Watchdog alarms"
  def kind_heading(:tile_marker), do: "Tile marker presets"

  @doc "Heroicon name for a preset kind."
  @spec kind_icon(atom()) :: String.t()
  def kind_icon(:watchdog_alarm), do: "hero-bell"
  def kind_icon(:tile_marker), do: "hero-squares-2x2"

  @doc "Name of the plugin a preset kind is imported into."
  @spec plugin_name(atom()) :: String.t()
  def plugin_name(:watchdog_alarm), do: "Watchdog"
  def plugin_name(:tile_marker), do: "Tile markers"

  @doc "Path of a preset kind's listing page."
  @spec kind_path(atom()) :: String.t()
  def kind_path(:watchdog_alarm), do: ~p"/watchdog"
  def kind_path(:tile_marker), do: ~p"/tile-markers"

  @doc "Path of the share form for a preset kind."
  @spec new_path(atom()) :: String.t()
  def new_path(:watchdog_alarm), do: ~p"/watchdog/new"
  def new_path(:tile_marker), do: ~p"/tile-markers/new"

  @doc "Coarse relative time, e.g. `5m ago`, `3h ago`, `12d ago`."
  @spec time_ago(DateTime.t(), DateTime.t()) :: String.t()
  def time_ago(datetime, now \\ DateTime.utc_now()) do
    seconds = DateTime.diff(now, datetime)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3600)}h ago"
      seconds < 2_592_000 -> "#{div(seconds, 86_400)}d ago"
      true -> Calendar.strftime(datetime, "%-d %b %Y")
    end
  end

  @doc "Relative time in a `<time>` element, with the absolute date as its tooltip."
  attr :at, DateTime, required: true
  attr :prefix, :string, default: nil
  attr :class, :string, default: nil

  def timestamp(assigns) do
    ~H"""
    <time
      datetime={DateTime.to_iso8601(@at)}
      title={Calendar.strftime(@at, "%-d %b %Y, %H:%M UTC")}
      class={@class}
    >
      {@prefix}{time_ago(@at)}
    </time>
    """
  end

  @doc "Display name of a preset's author."
  @spec author_name(map()) :: String.t()
  def author_name(%{author: %{name: name}}) when is_binary(name), do: name
  def author_name(_preset), do: "anonymous"

  @doc "Bordered box with a gold-ruled header bar."
  attr :id, :string, default: nil
  attr :title, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :string, default: nil
  slot :actions
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section
      id={@id}
      class={["overflow-hidden rounded-box border border-base-content/10 bg-base-100", @class]}
    >
      <div class="flex items-center gap-2 border-b border-l-2 border-base-content/10 border-l-primary bg-base-200 px-3 py-2">
        <h2 class="flex items-center gap-2 font-display text-sm font-bold tracking-wider uppercase">
          <.icon :if={@icon} name={@icon} class="size-4 text-primary" />
          {@title}
        </h2>
        <div :if={@actions != []} class="ml-auto flex items-center gap-2">
          {render_slot(@actions)}
        </div>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc "Google avatar, or initials when the user has none."
  attr :user, :any, required: true
  attr :class, :string, default: "size-6"

  def avatar(assigns) do
    ~H"""
    <%= if is_struct(@user) and @user.avatar_url do %>
      <img
        src={@user.avatar_url}
        alt=""
        class={["shrink-0 rounded-full", @class]}
        referrerpolicy="no-referrer"
      />
    <% else %>
      <span
        aria-hidden="true"
        class={[
          "inline-flex shrink-0 items-center justify-center rounded-full bg-neutral text-[0.5rem] font-bold text-neutral-content",
          @class
        ]}
      >
        {initials(@user)}
      </span>
    <% end %>
    """
  end

  @doc """
  Button that copies text to the clipboard: either `content` itself, or the text
  of the element whose id is `target`.
  """
  attr :id, :string, required: true
  attr :content, :string, default: nil
  attr :target, :string, default: nil
  attr :label, :string, default: nil, doc: "visible label; icon-only when nil"
  attr :class, :string, default: "btn btn-ghost btn-xs btn-square"
  attr :title, :string, default: "Copy the import string", doc: "hover text"

  attr :track, :string,
    default: nil,
    doc:
      "preset id; when set, the hook pushes a `\"copied\"` event `%{\"id\" => id}` to the LiveView"

  def copy_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      class={@class}
      phx-hook=".CopyToClipboard"
      data-content={@content}
      data-target={@target}
      data-track={@track}
      aria-label={@label || "Copy import string"}
      title={@title}
    >
      <.icon name="hero-clipboard-document" class="size-4 in-data-copied:hidden" />
      <.icon name="hero-check" class="hidden size-4 text-success in-data-copied:inline-block" />
      <span :if={@label} data-label>{@label}</span>
    </button>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyToClipboard">
      // The Clipboard API refuses unfocused or insecure pages; fall back to the
      // older select-and-copy so the button still works there.
      async function copyText(text) {
        try {
          await navigator.clipboard.writeText(text)
        } catch (_refused) {
          const area = document.createElement("textarea")
          area.value = text
          area.setAttribute("readonly", "")
          area.style.position = "fixed"
          area.style.opacity = "0"
          document.body.appendChild(area)
          area.select()
          const copied = document.execCommand("copy")
          area.remove()
          if (!copied) throw new Error("copy failed")
        }
      }

      export default {
        mounted() {
          this.el.addEventListener("click", async () => {
            const {content, target} = this.el.dataset
            const text = content ?? document.getElementById(target).textContent
            await copyText(text)
            if (this.el.dataset.track) this.pushEvent("copied", {id: this.el.dataset.track})
            this.el.dataset.copied = ""
            const label = this.el.querySelector("[data-label]")
            const original = label?.textContent
            if (label) label.textContent = "Copied!"
            setTimeout(() => {
              delete this.el.dataset.copied
              if (label) label.textContent = original
            }, 2000)
          })
        }
      }
    </script>
    """
  end

  @tile_map_squares Application.compile_env!(:runeshare, :tile_map_squares_url)

  @doc """
  Interactive map of a tile marker preset's tiles on the RuneScape Wiki's world
  map, in the preset's own colours and labels. Opens on the floor with the most
  tiles; buttons switch floors when there is more than one.
  """
  attr :id, :string, required: true
  attr :tiles, :list, required: true, doc: "decoded tiles, `Sharing.tile_marker_tiles/1`"

  def tile_map(assigns) do
    planes = assigns.tiles |> Enum.frequencies_by(& &1.plane) |> Enum.sort()
    {initial, _count} = Enum.max_by(planes, &elem(&1, 1))

    tiles =
      Enum.map(assigns.tiles, fn tile ->
        fill_alpha = if tile.filled, do: tile.fill_alpha, else: 0

        [
          tile.x,
          tile.z,
          tile.plane,
          tile.outline,
          tile.outline_alpha,
          tile.fill,
          fill_alpha,
          tile.label
        ]
      end)

    assigns =
      assign(assigns,
        planes: Enum.map(planes, &elem(&1, 0)),
        initial: initial,
        json: JSON.encode!(tiles),
        squares: @tile_map_squares
      )

    ~H"""
    <div
      id={@id}
      phx-hook=".TileMarkerMap"
      data-tiles={@json}
      data-squares={@squares}
      data-plane={@initial}
      class="relative isolate"
    >
      <div
        id={"#{@id}-canvas"}
        phx-update="ignore"
        data-canvas
        role="region"
        aria-label="Map of the marked tiles"
        class="h-72 bg-black sm:h-112"
      >
      </div>
      <div
        :if={length(@planes) > 1}
        class="absolute top-2 right-2 join z-1000 shadow"
        role="group"
        aria-label="Floor"
      >
        <button
          :for={plane <- @planes}
          type="button"
          data-plane={plane}
          aria-label={"Show #{floor_name(plane)}"}
          class={["btn join-item btn-xs", plane == @initial && "btn-primary"]}
          phx-click={
            JS.remove_class("btn-primary", to: "##{@id} [data-plane]")
            |> JS.add_class("btn-primary")
            |> JS.dispatch("tilemap:plane", detail: %{plane: plane})
          }
        >
          {floor_name(plane)}
        </button>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".TileMarkerMap">
      import * as L from "@/vendor/leaflet.js"

      // One map unit = one game tile; at zoom 2 a 256px square covers 64 tiles,
      // as on the wiki. The wiki numbers squares northwards, Leaflet southwards.
      const Squares = L.TileLayer.extend({
        getTileUrl(coords) {
          return L.Util.template(this._url, {
            z: coords.z, plane: this.options.plane, x: coords.x, y: -coords.y - 1
          })
        }
      })

      // Labels are text from the token: built as text nodes, never as HTML.
      function labelIcon(text) {
        const span = document.createElement("span")
        span.className = "tile-label"
        span.textContent = text
        return L.divIcon({html: span, className: "", iconSize: null})
      }

      // Open on where most tiles are: the ones within 128 tiles of the median tile,
      // so a stray tile far away doesn't zoom the map out to the whole world.
      function focus(tiles) {
        const median = values => values.sort((a, b) => a - b)[Math.floor(values.length / 2)]
        const mx = median(tiles.map(tile => tile[0]))
        const mz = median(tiles.map(tile => tile[1]))
        const near = tiles.filter(([x, z]) => Math.abs(x - mx) <= 128 && Math.abs(z - mz) <= 128)
        return L.latLngBounds(near.map(([x, z]) => [[z, x], [z + 1, x + 1]]).flat())
      }

      export default {
        mounted() {
          this.map = L.map(this.el.querySelector("[data-canvas]"), {
            crs: L.CRS.Simple, minZoom: -2, maxZoom: 5, preferCanvas: true
          })
          this.map.attributionControl.setPrefix(false)
          this.map.attributionControl.addAttribution(
            'Map: <a href="https://runescape.wiki/w/Map" target="_blank" rel="noopener">RuneScape Wiki</a>, © Jagex'
          )
          this.squares = new Squares(this.el.dataset.squares, {
            plane: 0, minZoom: -2, maxNativeZoom: 3, maxZoom: 5, noWrap: true
          }).addTo(this.map)
          this.marks = L.layerGroup().addTo(this.map)
          this.el.addEventListener("tilemap:plane", e => this.show(e.detail.plane))
          this.load()
        },

        // Switching version swaps the tiles; other page updates leave them alone.
        updated() { this.load() },

        destroyed() { this.map.remove() },

        load() {
          if (this.el.dataset.tiles === this.raw) return
          this.raw = this.el.dataset.tiles
          this.tiles = JSON.parse(this.raw)
          this.show(Number(this.el.dataset.plane))
        },

        show(plane) {
          this.squares.options.plane = plane
          this.squares.redraw()
          this.marks.clearLayers()
          const shown = this.tiles.filter(tile => tile[2] === plane)
          for (const [x, z, , outline, outlineAlpha, fill, fillAlpha, label] of shown) {
            L.rectangle([[z, x], [z + 1, x + 1]], {
              color: outline, opacity: outlineAlpha / 255, weight: 1.5,
              fillColor: fill, fillOpacity: fillAlpha / 255
            }).addTo(this.marks)
            if (label) L.marker([z + 0.5, x + 0.5], {icon: labelIcon(label), interactive: false}).addTo(this.marks)
          }
          this.map.fitBounds(focus(shown), {padding: [24, 24], maxZoom: 4})
        }
      }
    </script>
    """
  end

  defp floor_name(0), do: "Ground floor"
  defp floor_name(1), do: "1st floor"
  defp floor_name(2), do: "2nd floor"
  defp floor_name(3), do: "3rd floor"

  @doc "Like, comment and (when the preset has one) copy counts, for list rows."
  attr :preset, :any, required: true

  def counts(assigns) do
    assigns = assign(assigns, :copies, Map.get(assigns.preset, :copy_count))

    ~H"""
    <span class="inline-flex items-center gap-2 font-mono text-[11px] text-base-content/65">
      <span class="inline-flex items-center gap-0.5" title="Likes">
        <.icon name="hero-heart" class="size-3.5" />{@preset.like_count}
      </span>
      <span class="inline-flex items-center gap-0.5" title="Comments">
        <.icon name="hero-chat-bubble-left" class="size-3.5" />{@preset.comment_count}
      </span>
      <span :if={is_integer(@copies)} class="inline-flex items-center gap-0.5" title="Copies">
        <.icon name="hero-clipboard-document" class="size-3.5" />{@copies}
      </span>
    </span>
    """
  end

  @doc "A preset's author (avatar and name), linking to their public page."
  attr :preset, :any, required: true
  attr :avatar, :boolean, default: true
  attr :class, :string, default: "inline-flex items-center gap-1.5 sm:hover:text-primary"

  def author_link(assigns) do
    ~H"""
    <.link navigate={~p"/u/#{@preset.author_id}"} class={@class}>
      <.avatar :if={@avatar} user={@preset.author} class="size-5" />{author_name(@preset)}
    </.link>
    """
  end

  @doc "A preset's tags as small badges, each linking to `path.(tag)`."
  attr :tags, :list, required: true
  attr :path, :any, required: true, doc: "function from a tag to the listing path filtered by it"
  attr :patch, :boolean, default: true, doc: "patch (same LiveView) rather than navigate"
  attr :class, :string, default: nil

  def tag_badges(assigns) do
    ~H"""
    <div :if={@tags != []} class={["flex flex-wrap gap-1", @class]}>
      <%= for tag <- @tags do %>
        <.link :if={@patch} patch={@path.(tag)} class={tag_class()}>{tag}</.link>
        <.link :if={!@patch} navigate={@path.(tag)} class={tag_class()}>{tag}</.link>
      <% end %>
    </div>
    """
  end

  @doc """
  Records that `@visitor` copied preset `id`; `PresetCopy` counts each visitor once.
  The `:copied` MapSet skips repeat writes from the same page. For `"copied"`
  events from `copy_button/1`'s `track`.
  """
  @spec track_copy(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def track_copy(socket, id) do
    if MapSet.member?(socket.assigns.copied, id) do
      socket
    else
      %{visitor: visitor, current_user: user} = socket.assigns

      # A hidden, deleted or bogus id just isn't counted; nor is a visitor without a session.
      if visitor, do: Runeshare.Sharing.record_copy(id, visitor, actor: user)

      assign(socket, :copied, MapSet.put(socket.assigns.copied, id))
    end
  end

  @doc """
  `track_copy/2` for a preset card in a stream: on a first copy from this page the
  card is re-fetched and re-inserted, so its copy count goes up. `stream_name`
  maps the fresh preset to the stream it lives in.
  """
  @spec track_copy(Phoenix.LiveView.Socket.t(), String.t(), (struct() -> atom())) ::
          Phoenix.LiveView.Socket.t()
  def track_copy(socket, id, stream_name) do
    tracked = track_copy(socket, id)

    if tracked.assigns.copied == socket.assigns.copied,
      do: tracked,
      else: refresh_card(tracked, id, stream_name)
  end

  # The preset may be hidden or deleted by now; then the card stays as it is.
  defp refresh_card(socket, id, stream_name) do
    case Runeshare.Sharing.get_preset(id, actor: socket.assigns.current_user) do
      {:ok, preset} -> Phoenix.LiveView.stream_insert(socket, stream_name.(preset), preset)
      {:error, _error} -> socket
    end
  end

  @doc """
  Like toggle for a preset loaded with `:like_count` and `:liked_by_me`.
  Signed-out visitors get a link to sign in instead.
  """
  attr :preset, :any, required: true
  attr :current_user, :any, default: nil

  def like_button(assigns) do
    ~H"""
    <button
      :if={@current_user}
      id="like-button"
      type="button"
      phx-click="toggle_like"
      aria-pressed={to_string(@preset.liked_by_me)}
      title={if @preset.liked_by_me, do: "Remove your like", else: "Like this preset"}
      class={["group btn btn-sm", if(@preset.liked_by_me, do: "btn-primary", else: "btn-outline")]}
    >
      <.icon
        name={if @preset.liked_by_me, do: "hero-heart-solid", else: "hero-heart"}
        class={heart_class()}
      />
      <span>{if @preset.liked_by_me, do: "Liked", else: "Like"}</span>
      <span class="font-mono">{@preset.like_count}</span>
    </button>
    <.link
      :if={!@current_user}
      navigate={~p"/sign-in"}
      title="Sign in to like this preset"
      class="group btn btn-outline btn-sm"
    >
      <.icon name="hero-heart" class={heart_class()} /> Like
      <span class="font-mono">{@preset.like_count}</span>
    </.link>
    """
  end

  @doc "Placeholder rows while a list loads asynchronously."
  attr :rows, :integer, default: 4

  def skeleton_rows(assigns) do
    ~H"""
    <ul class="divide-y divide-base-content/5" aria-busy="true" aria-label="Loading">
      <li :for={_row <- 1..@rows} class="flex items-center gap-3 px-3 py-2.5">
        <div class="flex-1 space-y-1.5">
          <div class="h-3.5 w-2/3 skeleton"></div>
          <div class="h-2.5 w-1/3 skeleton"></div>
        </div>
        <div class="size-6 skeleton"></div>
      </li>
    </ul>
    """
  end

  @doc "Small breadcrumb trail; the last crumb is plain text."
  attr :crumbs, :list, required: true, doc: "list of `{label, path_or_nil}`"

  def breadcrumbs(assigns) do
    ~H"""
    <nav aria-label="Breadcrumb" class="text-xs text-base-content/65">
      <%= for {{label, path}, index} <- Enum.with_index(@crumbs) do %>
        <span :if={index > 0} aria-hidden="true">/</span>
        <.link :if={path} navigate={path} class="tap sm:hover:text-primary">{label}</.link>
        <span :if={!path}>{label}</span>
      <% end %>
    </nav>
    """
  end

  defp tag_class, do: "badge rounded-sm badge-ghost font-mono badge-xs"

  # The heart grows a little while its button is hovered or keyboard-focused.
  defp heart_class,
    do:
      "size-4 transition-transform group-focus-visible:scale-125 motion-reduce:transition-none sm:group-hover:scale-125"

  defp initials(%{name: name}) when is_binary(name) and name != "" do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp initials(_user), do: "?"
end
