defmodule RuneshareWeb.PresetLive.Show do
  @moduledoc """
  One preset: its newest version (or an older one under `/v/:number`), the
  version list, likes, comments, copy count and a share link. Its author can
  edit or delete it here; signed-in users can report it; admins can hide,
  unhide or delete it and remove any comment. Likes, comments, edits and
  moderation from other viewers arrive live.
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.PresetComponents
  import RuneshareWeb.PresetDetailComponents

  alias Phoenix.Socket.Broadcast
  alias Runeshare.Sharing
  alias Runeshare.Sharing.ImportString
  alias RuneshareWeb.Endpoint

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    preset = Sharing.get_preset!(id, actor: user)

    if connected?(socket) do
      Enum.each(~w(presets comments likes), &Endpoint.subscribe("#{&1}:#{preset.id}"))
    end

    socket =
      socket
      |> assign(preset: preset, version: nil, copied: MapSet.new(), report_form: nil)
      |> assign(og: og(preset))
      |> assign_comment_form()
      |> load_versions()
      |> load_comments()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"number" => number}, _uri, socket) do
    preset = socket.assigns.preset
    version = Sharing.get_preset_version!(preset.id, number)

    if version.number == preset.version do
      {:noreply, push_patch(socket, to: ~p"/presets/#{preset}", replace: true)}
    else
      socket = socket |> assign(version: version) |> put_shown()
      {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    socket = socket |> assign(version: nil) |> put_shown()
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("copied", %{"id" => id}, socket) do
    before = socket.assigns.copied
    socket = track_copy(socket, id)

    if socket.assigns.copied == before or id != socket.assigns.preset.id,
      do: {:noreply, socket},
      else: {:noreply, refresh_preset(socket)}
  end

  def handle_event("open_report", _params, socket) do
    form =
      [actor: socket.assigns.current_user]
      |> Sharing.form_to_report_preset()
      |> to_form()

    socket = assign(socket, report_form: form)
    {:noreply, socket}
  end

  def handle_event("close_report", _params, socket) do
    socket = assign(socket, report_form: nil)
    {:noreply, socket}
  end

  def handle_event("validate_report", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.report_form, params)
    socket = assign(socket, report_form: form)
    {:noreply, socket}
  end

  def handle_event("submit_report", %{"form" => params}, socket) do
    params = Map.put(params, "preset_id", socket.assigns.preset.id)

    case AshPhoenix.Form.submit(socket.assigns.report_form, params: params) do
      {:ok, _report} ->
        socket =
          socket
          |> assign(report_form: nil)
          |> put_flash(:info, "Thanks — a moderator will take a look.")

        {:noreply, socket}

      {:error, form} ->
        socket = assign(socket, report_form: form)
        {:noreply, socket}
    end
  end

  def handle_event("toggle_hidden", _params, socket) do
    %{preset: preset, current_user: user} = socket.assigns

    if preset.hidden do
      Sharing.unhide_preset!(preset, actor: user)
    else
      Sharing.hide_preset!(preset, actor: user)
    end

    {:noreply, refresh_preset(socket)}
  end

  def handle_event("delete", _params, socket) do
    %{preset: preset, current_user: user} = socket.assigns
    Endpoint.unsubscribe("presets:#{preset.id}")
    Sharing.delete_preset!(preset, actor: user)

    {:noreply,
     socket
     |> put_flash(:info, "Preset deleted")
     |> push_navigate(to: kind_path(preset.kind))}
  end

  def handle_event("toggle_like", _params, socket) do
    %{preset: preset, current_user: user} = socket.assigns

    if preset.liked_by_me do
      unlike(preset, user)
    else
      Sharing.like_preset!(preset.id, actor: user)
    end

    {:noreply, refresh_preset(socket)}
  end

  def handle_event("validate_comment", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.comment_form, params)
    socket = assign(socket, comment_form: form)
    {:noreply, socket}
  end

  def handle_event("post_comment", %{"form" => params}, socket) do
    params = Map.put(params, "preset_id", socket.assigns.preset.id)

    case AshPhoenix.Form.submit(socket.assigns.comment_form, params: params) do
      {:ok, comment} ->
        {:noreply,
         socket
         |> stream_insert(:comments, Sharing.get_comment!(comment.id))
         |> assign_comment_form()
         |> refresh_preset()}

      {:error, form} ->
        socket = assign(socket, comment_form: form)
        {:noreply, socket}
    end
  end

  def handle_event("delete_comment", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    comment = Sharing.get_comment!(id)
    Sharing.remove_comment!(comment, actor: user)

    {:noreply, socket |> stream_delete(:comments, comment) |> refresh_preset()}
  end

  @impl Phoenix.LiveView
  def handle_info(%Broadcast{topic: "presets:" <> _id, event: "destroy"}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "This preset was deleted.")
     |> push_navigate(to: kind_path(socket.assigns.preset.kind))}
  end

  def handle_info(%Broadcast{topic: "presets:" <> _id, event: "hide"}, socket) do
    %{preset: preset, current_user: user} = socket.assigns

    case Sharing.get_preset(preset.id, actor: user) do
      {:ok, _still_readable} ->
        {:noreply, refresh_preset(socket)}

      {:error, _gone} ->
        {:noreply,
         socket
         |> put_flash(:error, "This preset was removed by a moderator.")
         |> push_navigate(to: kind_path(preset.kind))}
    end
  end

  def handle_info(%Broadcast{topic: "presets:" <> _id}, socket) do
    {:noreply, socket |> refresh_preset() |> load_versions()}
  end

  def handle_info(%Broadcast{topic: "comments:" <> _id, event: "post", payload: payload}, socket) do
    socket =
      case Sharing.get_comment(payload.data.id) do
        {:ok, comment} -> stream_insert(socket, :comments, comment)
        {:error, _gone} -> socket
      end

    {:noreply, refresh_preset(socket)}
  end

  def handle_info(%Broadcast{topic: "comments:" <> _id, payload: payload}, socket) do
    {:noreply, socket |> stream_delete(:comments, payload.data) |> refresh_preset()}
  end

  def handle_info(%Broadcast{topic: "likes:" <> _id}, socket) do
    {:noreply, refresh_preset(socket)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active={@preset.kind}>
      <.breadcrumbs crumbs={[
        {"Home", ~p"/"},
        {kind_short(@preset.kind), kind_path(@preset.kind)},
        {@preset.title, nil}
      ]} />

      <div
        :if={@preset.hidden}
        id="hidden-banner"
        role="alert"
        class="alert rounded-box border border-error/40 bg-error/10 text-base-content"
      >
        <.icon name="hero-eye-slash" class="size-5 shrink-0 text-error" />
        <p class="text-sm">
          <strong>Hidden by a moderator.</strong> Only its author and moderators can see this preset.
        </p>
      </div>

      <.version_banner :if={@version} preset={@preset} version={@version} />

      <div class="flex flex-col justify-between gap-3 sm:flex-row sm:items-start">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <span class="badge rounded-sm font-display badge-sm tracking-wider uppercase badge-primary">
              <.icon name={kind_icon(@preset.kind)} class="size-3" /> {kind_short(@preset.kind)}
            </span>
            <span
              id="version-badge"
              class={[
                "badge rounded-sm font-mono badge-sm",
                if(@version, do: "badge-warning", else: "badge-outline")
              ]}
            >
              v{shown_number(@preset, @version)}
            </span>
          </div>
          <h1 class="mt-1 font-display text-2xl font-bold tracking-wide wrap-break-word uppercase sm:text-3xl">
            {@shown.title}
          </h1>
          <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-base-content/70">
            <.author_link preset={@preset} />
            <span aria-hidden="true">·</span>
            <span>
              Updated <.timestamp at={shown_at(@preset, @version)} />
            </span>
          </div>
          <div id="preset-tags" class="mt-2">
            <.tag_badges tags={@preset.tags} path={&tag_path(@preset.kind, &1)} patch={false} />
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <.like_button preset={@preset} current_user={@current_user} />
          <span id="copy-count" class="font-mono text-xs text-base-content/70" title="Copies">
            Copied {@preset.copy_count}×
          </span>
          <.copy_button
            id="share-preset"
            content={url(~p"/presets/#{@preset}")}
            label="Share"
            class="btn btn-outline btn-sm"
          />
          <button
            :if={@current_user && !owner?(@preset, @current_user) && !@report_form}
            type="button"
            class="btn btn-ghost btn-sm"
            phx-click="open_report"
          >
            <.icon name="hero-flag" class="size-4" /> Report
          </button>
          <button
            :if={admin?(@current_user)}
            id="toggle-hidden"
            type="button"
            class="btn btn-outline btn-sm btn-warning"
            phx-click="toggle_hidden"
          >
            <%= if @preset.hidden do %>
              <.icon name="hero-eye" class="size-4" /> Unhide
            <% else %>
              <.icon name="hero-eye-slash" class="size-4" /> Hide
            <% end %>
          </button>
          <.link
            :if={!@version and owner?(@preset, @current_user)}
            navigate={~p"/presets/#{@preset}/edit"}
            class="btn btn-outline btn-sm"
          >
            <.icon name="hero-pencil-square" class="size-4" /> Edit
          </.link>
          <button
            :if={!@version and (owner?(@preset, @current_user) or admin?(@current_user))}
            type="button"
            class="btn btn-outline btn-error btn-sm"
            phx-click="delete"
            data-confirm="Delete this preset?"
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </button>
        </div>
      </div>

      <.report_form :if={@report_form} form={@report_form} />

      <div class="grid gap-4 lg:grid-cols-[1fr_17rem]">
        <div class="min-w-0 space-y-4">
          <img
            :if={@preset.cover_image_url}
            id="cover-image"
            src={@preset.cover_image_url}
            alt={"Cover image for #{@preset.title}"}
            class="aspect-video w-full rounded-box border border-base-content/10 bg-base-200 object-cover"
          />
          <.panel title="Import string">
            <:actions>
              <span class="font-mono text-xs text-base-content/60">
                {String.length(@shown.content)} chars
              </span>
              <.copy_button
                id="copy-preset"
                target="preset-content"
                track={@preset.id}
                label="Copy string"
                class="btn hidden btn-primary btn-sm sm:inline-flex"
              />
            </:actions>
            <pre
              id="preset-content"
              class="max-h-56 overflow-auto bg-base-300/40 p-3 font-mono text-xs/relaxed break-all whitespace-pre-wrap text-base-content/80"
            >{@shown.content}</pre>
            <div class="border-t border-base-content/10 p-2 sm:hidden">
              <.copy_button
                id="copy-preset-mobile"
                target="preset-content"
                track={@preset.id}
                label="Copy string"
                class="btn btn-block btn-primary"
              />
            </div>
          </.panel>

          <.alert_summary :if={@alerts != []} alerts={@alerts} />

          <.panel :if={@shown.description} title="Description">
            <%!-- Inline on purpose: whitespace-pre-line would render template newlines. --%>
            <p class="p-3 text-sm/relaxed whitespace-pre-line text-base-content/80" phx-no-format>{@shown.description}</p>
          </.panel>

          <.panel
            id="preset-comments"
            title={"Comments (#{@preset.comment_count})"}
            icon="hero-chat-bubble-left"
          >
            <.async_result assign={@comments}>
              <:loading><.skeleton_rows rows={2} /></:loading>
              <:failed>
                <p class="p-3 text-sm text-error">Couldn't load comments.</p>
              </:failed>
            </.async_result>
            <ul id="comments" phx-update="stream" class="divide-y divide-base-content/5">
              <li
                :if={@comments.ok?}
                id="comments-empty"
                class="hidden p-3 text-sm text-base-content/65 only:block"
              >
                No comments yet.
              </li>
              <.comment_row
                :for={{dom_id, comment} <- @streams.comments}
                id={dom_id}
                comment={comment}
                preset={@preset}
                can_delete={can_delete?(comment, @preset, @current_user)}
              />
            </ul>
            <div class="border-t border-base-content/10 p-3">
              <.form
                :if={@current_user}
                for={@comment_form}
                id="comment-form"
                phx-change="validate_comment"
                phx-submit="post_comment"
              >
                <.input
                  field={@comment_form[:body]}
                  type="textarea"
                  label="Add a comment"
                  rows="3"
                  maxlength="2000"
                />
                <div class="flex justify-end">
                  <button
                    type="submit"
                    class="btn w-full btn-primary btn-sm sm:w-auto"
                    phx-disable-with="Posting..."
                  >
                    <.icon name="hero-paper-airplane" class="size-4" /> Post comment
                  </button>
                </div>
              </.form>
              <p :if={!@current_user} class="text-sm text-base-content/70">
                <.link navigate={~p"/sign-in"} class="link link-primary">Sign in to comment</.link>
              </p>
            </div>
          </.panel>
        </div>

        <aside class="space-y-4">
          <.versions_panel
            versions={@versions}
            preset={@preset}
            viewing={shown_number(@preset, @version)}
          />
          <.panel title="Details">
            <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 p-3 text-sm">
              <dt class="text-base-content/65">Kind</dt>
              <dd>{kind_label(@preset.kind)}</dd>
              <dt class="text-base-content/65">Author</dt>
              <dd><.author_link preset={@preset} avatar={false} class="link link-hover" /></dd>
              <dt class="text-base-content/65">Shared</dt>
              <dd>{Calendar.strftime(@preset.inserted_at, "%-d %b %Y")}</dd>
              <dt class="text-base-content/65">Updated</dt>
              <dd><.timestamp at={shown_at(@preset, @version)} /></dd>
              <dt class="text-base-content/65">Version</dt>
              <dd class="font-mono">
                v{shown_number(@preset, @version)}
                <span :if={@version} class="text-base-content/65">of v{@preset.version}</span>
              </dd>
              <dt class="text-base-content/65">Copied</dt>
              <dd id="details-copy-count" class="font-mono">{@preset.copy_count}×</dd>
            </dl>
          </.panel>
          <.panel title="How to import">
            <ol class="list-inside list-decimal space-y-1 p-3 text-sm text-base-content/80">
              <li>Copy the string above.</li>
              <li :for={step <- import_steps(@preset.kind)}>{step}</li>
            </ol>
          </.panel>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  defp put_shown(socket) do
    shown = socket.assigns.version || socket.assigns.preset

    assign(socket,
      shown: shown,
      page_title: shown.title,
      alerts: ImportString.watchdog_summary(shown.content)
    )
  end

  defp refresh_preset(socket) do
    %{preset: preset, current_user: user} = socket.assigns

    socket
    |> assign(preset: Sharing.get_preset!(preset.id, actor: user))
    |> put_shown()
  end

  defp load_versions(socket) do
    preset_id = socket.assigns.preset.id

    assign_async(socket, :versions, fn ->
      {:ok, %{versions: Sharing.list_preset_versions!(preset_id)}}
    end)
  end

  defp load_comments(socket) do
    preset_id = socket.assigns.preset.id
    stream_async(socket, :comments, fn -> {:ok, Sharing.list_comments!(preset_id)} end)
  end

  defp assign_comment_form(%{assigns: %{current_user: nil}} = socket),
    do: assign(socket, comment_form: nil)

  defp assign_comment_form(socket) do
    form =
      [actor: socket.assigns.current_user]
      |> Sharing.form_to_post_comment()
      |> to_form()

    assign(socket, comment_form: form)
  end

  defp shown_number(preset, nil), do: preset.version
  defp shown_number(_preset, version), do: version.number

  defp shown_at(preset, nil), do: preset.updated_at
  defp shown_at(_preset, version), do: version.inserted_at

  defp import_steps(:tile_marker) do
    [
      "Enable Tilemarkers in the Plugin Hub.",
      "In its Presets tab click Import preset (or right-click the World Map button → Import Tilemarkers Preset).",
      "Paste the whole token and click Import. Markers keep their saved locations."
    ]
  end

  defp import_steps(:watchdog_alarm) do
    [
      "Enable Watchdog in the Plugin Hub.",
      "Use Watchdog's import option and paste the whole JSON."
    ]
  end

  @og_description_length 200

  defp og(preset) do
    label = kind_label(preset.kind)

    description =
      preset.description ||
        "#{label} by #{author_name(preset)}. Copy the import string and paste it into the plugin."

    %{
      title: "#{preset.title} — #{label} v#{preset.version}",
      description: truncate(description, @og_description_length),
      url: url(~p"/presets/#{preset}"),
      image: preset.cover_image_url
    }
  end

  defp truncate(text, max) do
    text = text |> String.replace(~r/\s+/, " ") |> String.trim()

    if String.length(text) > max,
      do: String.slice(text, 0, max - 1) <> "…",
      else: text
  end

  # This page can be a step behind: the like may already be gone (another tab).
  defp unlike(preset, user) do
    case Sharing.unlike_preset(preset.id, user.id, actor: user) do
      :ok -> :ok
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} -> :ok
    end
  end

  defp admin?(user), do: user != nil and user.role == :admin

  defp owner?(preset, user), do: user != nil and preset.author_id == user.id

  defp can_delete?(_comment, _preset, nil), do: false

  defp can_delete?(comment, preset, user),
    do: admin?(user) or comment.author_id == user.id or preset.author_id == user.id
end
