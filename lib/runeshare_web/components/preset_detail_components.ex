defmodule RuneshareWeb.PresetDetailComponents do
  @moduledoc """
  Pieces of the preset detail page: the older-version banner, the
  version list, comment rows, the Watchdog alert summary and the report
  form.
  """

  use RuneshareWeb, :html

  import RuneshareWeb.PresetComponents

  @doc "Highlighted notice that an older version is on screen."
  attr :preset, :any, required: true
  attr :version, :any, required: true

  def version_banner(assigns) do
    ~H"""
    <div
      id="version-banner"
      role="alert"
      class="alert flex-col items-start gap-2 rounded-box border border-warning/40 bg-warning/10 text-base-content sm:flex-row sm:items-center"
    >
      <.icon name="hero-clock" class="size-5 shrink-0 text-warning" />
      <p class="text-sm">
        You're viewing <strong class="font-mono">v{@version.number}</strong>
        from <span title={absolute_date(@version.inserted_at)}>{date(@version.inserted_at)}</span>.
        <strong>A newer version (v{@preset.version}) is available.</strong>
        <span :if={@version.note} class="mt-1 block text-base-content/70">
          v{@version.number}: {@version.note}
        </span>
      </p>
      <.link patch={~p"/presets/#{@preset}"} class="btn btn-sm btn-warning sm:ml-auto">
        View latest <.icon name="hero-arrow-right" class="size-4" />
      </.link>
    </div>
    """
  end

  @shown_versions 3

  @doc """
  A preset's versions, newest first, each linking to its page. The newest
  #{@shown_versions} and the one on screen are listed; older ones fold away
  behind "Show N older versions".
  """
  attr :versions, :any, required: true, doc: "AsyncResult holding a list of PresetVersion"
  attr :preset, :any, required: true
  attr :viewing, :integer, required: true, doc: "number of the version on screen"

  def versions_panel(assigns) do
    ~H"""
    <.panel id="preset-versions" title="Versions" icon="hero-clock">
      <.async_result :let={versions} assign={@versions}>
        <:loading><.skeleton_rows rows={2} /></:loading>
        <:failed>
          <p class="p-3 text-sm text-error">Couldn't load versions.</p>
        </:failed>
        <% {shown, older} = split_versions(versions, @viewing) %>
        <ul id="versions" class="divide-y divide-base-content/5 text-sm">
          <.version_row :for={version <- shown} version={version} preset={@preset} viewing={@viewing} />
        </ul>
        <details :if={older != []} id="older-versions" class="border-t border-base-content/5 text-sm">
          <summary class="cursor-pointer px-3 py-2 text-xs text-base-content/70 focus-visible:text-primary sm:hover:bg-base-200/60 sm:hover:text-primary">
            Show {length(older)} older {if length(older) == 1, do: "version", else: "versions"}
          </summary>
          <ul class="divide-y divide-base-content/5">
            <.version_row
              :for={version <- older}
              version={version}
              preset={@preset}
              viewing={@viewing}
            />
          </ul>
        </details>
      </.async_result>
    </.panel>
    """
  end

  # Newest first: the newest few plus the one on screen, and the rest.
  defp split_versions(versions, viewing) do
    {newest, rest} = Enum.split(versions, @shown_versions)
    {current, older} = Enum.split_with(rest, &(&1.number == viewing))
    {newest ++ current, older}
  end

  attr :version, :any, required: true
  attr :preset, :any, required: true
  attr :viewing, :integer, required: true

  defp version_row(assigns) do
    ~H"""
    <li id={"version-#{@version.number}"}>
      <.link
        patch={version_path(@preset, @version.number)}
        aria-current={@version.number == @viewing && "page"}
        class={[
          "flex items-center gap-2 px-3 py-2 sm:hover:bg-base-200/60",
          @version.number == @viewing && "border-l-2 border-l-primary bg-base-200/60"
        ]}
      >
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <span class="font-mono font-bold text-primary">v{@version.number}</span>
            <span
              :if={@version.number == @preset.version}
              class="badge rounded-sm font-display badge-xs tracking-wider uppercase badge-primary"
            >
              Latest
            </span>
            <span class="ml-auto text-xs text-base-content/65">
              <.timestamp at={@version.inserted_at} />
            </span>
          </div>
          <p
            :if={@version.note}
            class="mt-0.5 truncate text-xs text-base-content/70"
            title={@version.note}
          >
            {@version.note}
          </p>
        </div>
      </.link>
    </li>
    """
  end

  @doc "One comment row for the comments stream."
  attr :id, :string, required: true
  attr :comment, :any, required: true
  attr :preset, :any, required: true, doc: "the preset, for the older-version badge"
  attr :can_delete, :boolean, default: false

  def comment_row(assigns) do
    ~H"""
    <li id={@id} class="flex gap-3 p-3">
      <.avatar user={@comment.author} class="size-7" />
      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-2 text-xs text-base-content/65">
          <span class="font-bold text-base-content/80">{author_name(@comment)}</span>
          <.timestamp at={@comment.inserted_at} />
          <.link
            :if={@comment.preset_version < @preset.version}
            patch={version_path(@preset, @comment.preset_version)}
            class="badge rounded-sm badge-ghost font-mono badge-xs"
            title={"Posted when v#{@comment.preset_version} was current"}
          >
            on v{@comment.preset_version}
          </.link>
          <button
            :if={@can_delete}
            type="button"
            phx-click="delete_comment"
            phx-value-id={@comment.id}
            data-confirm="Delete this comment?"
            class="btn ml-auto btn-square btn-ghost text-base-content/65 btn-xs focus-visible:text-error sm:hover:text-error"
          >
            <.icon name="hero-trash" class="size-3.5" />
            <span class="sr-only">Delete comment</span>
          </button>
        </div>
        <%!-- Inline on purpose: whitespace-pre-line would render template newlines. --%>
        <p
          class="mt-1 text-sm/relaxed wrap-break-word whitespace-pre-line text-base-content/80"
          phx-no-format
        >{@comment.body}</p>
      </div>
    </li>
    """
  end

  @doc "Readable trigger/action summary of each alert in a Watchdog export."
  attr :alerts, :list, required: true, doc: "from `ImportString.watchdog_summary/1`"

  def alert_summary(assigns) do
    ~H"""
    <.panel id="preset-alerts" title="Alerts in this export" icon="hero-bell">
      <ul class="divide-y divide-base-content/5 text-sm">
        <li :for={alert <- @alerts} class="px-3 py-2">
          <p class="font-bold wrap-break-word">{alert.name}</p>
          <dl class="mt-1 grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 text-xs">
            <dt class="font-display tracking-wider text-base-content/65 uppercase">When</dt>
            <dd class="text-base-content/80">{summary_list(alert.triggers)}</dd>
            <dt class="font-display tracking-wider text-base-content/65 uppercase">Then</dt>
            <dd class="text-base-content/80">{summary_list(alert.actions)}</dd>
          </dl>
        </li>
      </ul>
    </.panel>
    """
  end

  @doc "Inline report form: a reason and an optional note for moderators."
  attr :form, :any, required: true

  def report_form(assigns) do
    ~H"""
    <.panel id="report-panel" title="Report this preset" icon="hero-flag">
      <.form
        for={@form}
        id="report-form"
        phx-change="validate_report"
        phx-submit="submit_report"
        class="p-3"
      >
        <.input
          field={@form[:reason]}
          type="select"
          label="Reason"
          options={[
            {"Spam", "spam"},
            {"Broken / doesn't import", "broken"},
            {"Offensive", "offensive"},
            {"Other", "other"}
          ]}
        />
        <.input
          field={@form[:note]}
          type="textarea"
          label="Note (optional)"
          rows="2"
          maxlength="500"
        />
        <div class="flex justify-end gap-2">
          <button type="button" class="btn btn-ghost btn-sm" phx-click="close_report">
            Cancel
          </button>
          <button type="submit" class="btn btn-primary btn-sm" phx-disable-with="Sending...">
            Send report
          </button>
        </div>
      </.form>
    </.panel>
    """
  end

  @doc "Path of a version's page; the newest version lives at the preset's own path."
  @spec version_path(map(), integer()) :: String.t()
  def version_path(%{version: number} = preset, number), do: ~p"/presets/#{preset}"
  def version_path(preset, number), do: ~p"/presets/#{preset}/v/#{number}"

  @doc "The kind listing narrowed to one tag."
  @spec tag_path(atom(), String.t()) :: String.t()
  def tag_path(kind, tag), do: kind_path(kind) <> "?tag=" <> URI.encode_www_form(tag)

  defp summary_list([]), do: "—"
  defp summary_list(labels), do: Enum.join(labels, ", ")

  defp date(at), do: Calendar.strftime(at, "%-d %b %Y")

  defp absolute_date(at), do: Calendar.strftime(at, "%-d %b %Y, %H:%M UTC")
end
