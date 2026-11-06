defmodule RuneshareWeb.PresetLive.Form do
  @moduledoc """
  Share a new preset (kind from the live action) or edit one of your own.
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.PresetComponents

  alias Runeshare.Sharing
  alias Runeshare.Sharing.ImportString
  alias Runeshare.Sharing.Preset.Changes.NormalizeTags
  alias Runeshare.Sharing.Preset.Changes.SnapshotVersion
  alias Runeshare.Sharing.Preset.Validations.CoverImage

  # Inputs rendered with their own error messages; anything else shows above the buttons.
  @field_inputs [:title, :description, :content, :tags, :change_note, :cover_image]

  # Typed fields stay quiet until the user leaves them once ("touch"); from then on
  # their errors update live. The import string is pasted whole, so it's checked at once.
  @touchable ~w(title description tags change_note)

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # The browser shrinks the picture first (`.ShrinkImage` hook), so the limit is generous.
    socket =
      allow_upload(socket, :cover_image,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: CoverImage.max_bytes()
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, assign_form(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"form" => params} = event, socket) do
    tags_text = Map.get(event, "tags_text", socket.assigns.tags_text)

    params =
      params
      |> maybe_suggest_title(socket.assigns.kind)
      |> Map.put("tags", split_tags(tags_text))

    socket =
      socket
      |> assign(form: AshPhoenix.Form.validate(socket.assigns.form, params))
      |> assign(tags_text: tags_text)
      |> assign_duplicates(Map.get(params, "content", ""))

    {:noreply, socket}
  end

  def handle_event("touch", %{"field" => field}, socket) when field in @touchable do
    socket = update(socket, :touched, &MapSet.put(&1, field))
    {:noreply, socket}
  end

  def handle_event("cancel_cover_image", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cover_image, ref)}
  end

  def handle_event("save", %{"form" => params} = event, socket) do
    tags_text = Map.get(event, "tags_text", socket.assigns.tags_text)
    params = Map.put(params, "tags", split_tags(tags_text))
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    # Only take the picked image once everything else is valid, so a typo
    # elsewhere doesn't make the user pick it again.
    if form.source.valid? do
      {:noreply, submit(socket, params)}
    else
      socket = assign(socket, form: form, touched: MapSet.new(@touchable))
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active={@kind} width="max-w-3xl">
      <div>
        <.breadcrumbs crumbs={[
          {"Home", ~p"/"},
          {kind_short(@kind), kind_path(@kind)},
          {if(@preset, do: "Edit", else: "Share"), nil}
        ]} />
        <h1 class="font-display text-xl font-bold tracking-wide uppercase sm:text-2xl">
          {@page_title}
        </h1>
      </div>

      <.form
        for={@form}
        id="preset-form"
        phx-change="validate"
        phx-submit="save"
        class="overflow-hidden rounded-box border border-base-content/10 bg-base-100"
      >
        <div class="border-b border-l-2 border-base-content/10 border-l-primary bg-base-200 px-3 py-2">
          <h2 class="flex items-center gap-2 font-display text-sm font-bold tracking-wider uppercase">
            {if @preset, do: "Edit preset", else: "New preset"}
            <span
              :if={@preset}
              id="current-version"
              class="badge rounded-sm badge-ghost font-mono badge-sm normal-case"
            >
              v{@preset.version}
            </span>
          </h2>
        </div>
        <div class="p-3 sm:p-4">
          <fieldset :if={@live_action != :edit} class="fieldset">
            <legend class="fieldset-legend">Kind</legend>
            <div class="join w-full sm:w-auto">
              <.link
                :for={kind <- Runeshare.Sharing.Preset.kinds()}
                patch={new_path(kind)}
                class={["btn join-item flex-1 btn-sm", kind == @kind && "btn-primary"]}
              >
                {kind_short(kind)}
              </.link>
            </div>
          </fieldset>
          <.input
            field={@form[:title]}
            label="Title"
            placeholder="e.g. Vorago rotation timer"
            required
            show_errors={"title" in @touched}
            phx-blur="touch"
            phx-value-field="title"
          />
          <.input
            field={@form[:description]}
            type="textarea"
            label="Description (optional)"
            placeholder="Which boss, which phases, anything people should tweak."
            class="textarea h-24 w-full"
            show_errors={"description" in @touched}
            phx-blur="touch"
            phx-value-field="description"
          />
          <.input
            field={@form[:content]}
            type="textarea"
            label="Import string"
            placeholder={content_placeholder(@kind)}
            class="textarea h-40 w-full font-mono text-xs/relaxed break-all"
            required
          />
          <div
            :if={@duplicates != []}
            id="duplicate-warning"
            role="status"
            class="mb-2 alert alert-soft text-sm alert-warning"
          >
            <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
            <span>
              This exact string is already shared as
              <.link navigate={~p"/presets/#{hd(@duplicates)}"} class="link font-medium">
                {hd(@duplicates).title}
              </.link>
              by {author_name(hd(@duplicates))}.
              <span :if={length(@duplicates) > 1} class="text-base-content/70">
                (+{length(@duplicates) - 1} more)
              </span>
            </span>
          </div>
          <.cover_image_field
            upload={@uploads.cover_image}
            field={@form[:cover_image]}
            remove_field={@form[:remove_cover_image]}
            current_url={@preset && @preset.cover_image_url}
          />
          <.input
            name="tags_text"
            id="preset-tags"
            label="Tags (optional)"
            value={@tags_text}
            errors={if "tags" in @touched, do: tag_errors(@form), else: []}
            placeholder="e.g. vorago, hard mode"
            autocomplete="off"
            phx-debounce="300"
            phx-blur="touch"
            phx-value-field="tags"
          />
          <p class="-mt-1 mb-2 text-xs text-base-content/65">Up to 5, e.g. boss or skill</p>
          <div
            :if={split_tags(@tags_text) != []}
            id="tag-preview"
            class="mb-2 flex flex-wrap gap-1"
          >
            <span
              :for={tag <- split_tags(@tags_text)}
              class="badge rounded-sm badge-ghost font-mono badge-sm"
            >
              {tag}
            </span>
          </div>
          <.input
            :if={@preset}
            field={@form[:change_note]}
            label="What changed? (optional)"
            placeholder="e.g. Added the P5 enrage alert"
            maxlength="200"
            show_errors={"change_note" in @touched}
            phx-blur="touch"
            phx-value-field="change_note"
          />
          <div :if={base_errors(@form) != []} id="form-errors" role="alert" class="space-y-1">
            <p
              :for={message <- base_errors(@form)}
              class="flex items-center gap-2 text-sm text-error"
            >
              <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
              {message}
            </p>
          </div>
        </div>
        <div class="flex flex-col-reverse gap-2 border-t border-base-content/10 bg-base-200 px-3 py-2 sm:flex-row sm:items-center sm:justify-end">
          <p
            :if={@preset}
            id="next-version"
            class="text-center text-xs text-base-content/70 sm:mr-auto sm:text-left"
          >
            <%= if new_version?(@form) do %>
              Saving will create <span class="font-mono text-primary">v{@preset.version + 1}</span>.
              Older versions stay available.
            <% else %>
              Nothing versioned changed yet — saving keeps <span class="font-mono text-primary">v{@preset.version}</span>.
            <% end %>
          </p>
          <.link navigate={kind_path(@kind)} class="btn btn-ghost btn-sm">Cancel</.link>
          <button type="submit" class="btn btn-primary btn-sm" phx-disable-with="Saving…">
            Save preset
          </button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  attr :upload, Phoenix.LiveView.UploadConfig, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :remove_field, Phoenix.HTML.FormField, required: true
  attr :current_url, :string, default: nil

  # Picker, preview of the picked image, the current one (when editing) and errors.
  defp cover_image_field(assigns) do
    ~H"""
    <fieldset class="fieldset" phx-drop-target={@upload.ref}>
      <label for={@upload.ref} class="fieldset-legend">Cover image (optional)</label>
      <div id="cover-image-picker" phx-hook=".ShrinkImage">
        <.live_file_input upload={@upload} class="file-input w-full" />
      </div>
      <p class="text-xs text-base-content/65">
        JPEG, PNG or WebP — e.g. a screenshot of the markers in game. Large pictures are shrunk before upload.
      </p>

      <div
        :for={entry <- @upload.entries}
        id={"cover-entry-#{entry.ref}"}
        class="mt-2 flex items-start gap-3"
      >
        <.live_img_preview
          entry={entry}
          class="h-24 w-40 rounded-box border border-base-content/10 object-cover"
        />
        <div class="min-w-0 flex-1 space-y-1">
          <p class="truncate text-sm">{entry.client_name}</p>
          <progress class="progress w-full progress-primary" value={entry.progress} max="100">
            {entry.progress}%
          </progress>
          <p :for={error <- upload_errors(@upload, entry)} class="text-sm text-error">
            {upload_error_message(error)}
          </p>
        </div>
        <button
          type="button"
          class="btn btn-ghost btn-sm"
          phx-click="cancel_cover_image"
          phx-value-ref={entry.ref}
          aria-label="Remove the picked image"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <div :if={@current_url && @upload.entries == []} id="current-cover-image" class="mt-2 space-y-2">
        <img
          src={@current_url}
          alt="Current cover image"
          class="h-24 w-40 rounded-box border border-base-content/10 object-cover"
        />
        <.input field={@remove_field} type="checkbox" label="Remove the current image" />
      </div>

      <p :for={error <- upload_errors(@upload)} class="text-sm text-error">
        {upload_error_message(error)}
      </p>
      <p :for={error <- @field.errors} class="text-sm text-error">
        {translate_error(error)}
      </p>
    </fieldset>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ShrinkImage">
      // Shrinks a picked image (longest side 1600 px, re-encoded as WebP, or JPEG
      // where the browser can't write WebP) before LiveView uploads it. Re-encoding
      // also drops EXIF data such as GPS location. Anything that can't be decoded
      // is passed on untouched; the server checks it either way.
      const MAX_SIDE = 1600
      const QUALITY = 0.85

      const toBlob = (canvas, type) =>
        new Promise((resolve) => canvas.toBlob(resolve, type, QUALITY))

      async function shrink(file) {
        const bitmap = await createImageBitmap(file)
        const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height))
        const canvas = document.createElement("canvas")
        canvas.width = Math.round(bitmap.width * scale)
        canvas.height = Math.round(bitmap.height * scale)
        canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)
        bitmap.close()

        let blob = await toBlob(canvas, "image/webp")
        if (!blob || blob.type !== "image/webp") blob = await toBlob(canvas, "image/jpeg")
        const ext = blob.type === "image/webp" ? "webp" : "jpg"
        const name = file.name.replace(/\.[^.]+$/, "") + "." + ext
        return new File([blob], name, {type: blob.type})
      }

      export default {
        mounted() {
          // LiveView listens on window, so catching the events on the way down
          // lets the file be swapped before LiveView reads the input.
          const intercept = async (event) => {
            const input = event.target
            if (this.passing || input.type !== "file" || !input.files?.length) return
            event.stopPropagation()
            if (event.type !== "change") return

            let file = input.files[0]
            try {
              file = await shrink(file)
            } catch (_undecodable) {}

            const files = new DataTransfer()
            files.items.add(file)
            input.files = files.files

            this.passing = true
            input.dispatchEvent(new Event("input", {bubbles: true}))
            this.passing = false
          }

          this.el.addEventListener("input", intercept, true)
          this.el.addEventListener("change", intercept, true)
        }
      }
    </script>
    """
  end

  defp upload_error_message(:too_large), do: "is larger than 2 MB, even after shrinking"
  defp upload_error_message(:not_accepted), do: "must be a JPEG, PNG or WebP image"
  defp upload_error_message(:too_many_files), do: "pick just one image"
  defp upload_error_message(_other), do: "couldn't be uploaded — please try again"

  defp submit(socket, params) do
    {params, copies} = put_cover_image(socket, params)

    try do
      case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
        {:ok, preset} ->
          socket
          |> put_flash(:info, "Preset saved")
          |> push_navigate(to: ~p"/presets/#{preset}")

        {:error, form} ->
          assign(socket, form: form, touched: MapSet.new(@touchable))
      end
    after
      Enum.each(copies, &File.rm/1)
    end
  end

  # LiveView deletes an upload's temp file when consuming ends, but the action
  # reads it afterwards, so it works on a copy (removed after submitting).
  defp put_cover_image(socket, params) do
    uploads =
      consume_uploaded_entries(socket, :cover_image, fn %{path: path}, entry ->
        copy = Plug.Upload.random_file!("cover")
        File.cp!(path, copy)

        {:ok,
         %Plug.Upload{path: copy, filename: entry.client_name, content_type: entry.client_type}}
      end)

    case uploads do
      [upload] -> {Map.put(params, "cover_image", upload), [upload.path]}
      [] -> {params, []}
    end
  end

  # Exports carry their own name; use it when the user hasn't typed a title yet.
  defp maybe_suggest_title(%{"title" => title, "content" => content} = params, kind)
       when title in [nil, ""] do
    case ImportString.suggested_title(kind, String.trim(content)) do
      nil -> params
      suggested -> Map.put(params, "title", String.slice(suggested, 0, 100))
    end
  end

  defp maybe_suggest_title(params, _kind), do: params

  defp new_version?(form), do: SnapshotVersion.new_version?(form.source.source)

  defp split_tags(text), do: text |> String.split(",") |> NormalizeTags.normalize()

  defp tag_errors(form), do: Enum.map(form[:tags].errors, &translate_error/1)

  defp base_errors(form) do
    for {field, message} <- AshPhoenix.Form.errors(form), field not in @field_inputs, do: message
  end

  # Only looks the string up when it changed and looks like a real export of this kind.
  defp assign_duplicates(%{assigns: %{checked_content: content}} = socket, content), do: socket

  defp assign_duplicates(socket, raw_content) do
    %{kind: kind, preset: preset, current_user: user} = socket.assigns
    content = String.trim(raw_content)

    duplicates =
      if content != "" and ImportString.check(kind, content) == :ok do
        kind
        |> Sharing.find_duplicate_presets!(content, actor: user)
        |> Enum.reject(&(preset && &1.id == preset.id))
        |> with_first_author(user)
      else
        []
      end

    assign(socket, duplicates: duplicates, checked_content: raw_content)
  end

  # The warning names the first match's author; `get_preset` loads it.
  defp with_first_author([], _user), do: []

  defp with_first_author([first | rest], user) do
    case Sharing.get_preset(first.id, actor: user) do
      {:ok, loaded} -> [loaded | rest]
      {:error, _reason} -> rest
    end
  end

  defp content_placeholder(:watchdog_alarm),
    do: ~s(Watchdog → export, then paste the whole JSON starting with {"schemaVersion")

  defp content_placeholder(:tile_marker),
    do: "Tilemarkers → Presets → Export preset, then paste the whole TM2… token"

  defp assign_form(socket, :edit, %{"id" => id}) do
    user = socket.assigns.current_user
    preset = Sharing.get_preset!(id, actor: user)

    form =
      preset
      |> Sharing.form_to_edit_preset(actor: user)
      |> to_form()

    socket
    |> assign(
      form: form,
      kind: preset.kind,
      preset: preset,
      page_title: "Edit #{preset.title}",
      tags_text: Enum.join(preset.tags, ", ")
    )
    |> assign(duplicates: [], checked_content: preset.content, touched: MapSet.new())
  end

  defp assign_form(socket, kind, _params) do
    form =
      [
        actor: socket.assigns.current_user,
        prepare_source: &Ash.Changeset.change_attribute(&1, :kind, kind)
      ]
      |> Sharing.form_to_share_preset()
      |> to_form()

    socket
    |> assign(
      form: form,
      kind: kind,
      preset: nil,
      page_title: "Share a #{kind_label(kind)}",
      tags_text: ""
    )
    |> assign(duplicates: [], checked_content: "", touched: MapSet.new())
  end
end
