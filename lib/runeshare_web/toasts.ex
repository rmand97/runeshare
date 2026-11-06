defmodule RuneshareWeb.Toasts do
  @moduledoc """
  Toast notifications (LiveToast), styled with the DaisyUI theme.

  - `toast/3` shows a toast on the current page. Toasts stack, unlike flashes.
  - `put_flash/3` still works for messages that must survive a navigation
    (`push_navigate`, redirects); LiveToast renders those as toasts too.
  - No connection ("can't find the internet") notices: they're switched off in
    `Layouts.app`.
  """

  @duration 5_000

  @doc "How long a toast or flash stays up, in milliseconds (paused while hovered)."
  @spec duration() :: pos_integer()
  def duration, do: @duration

  @doc """
  Shows a toast in the current LiveView and returns the socket, so it fits a pipeline.

      socket |> assign(...) |> toast(:info, "Display name saved")
  """
  @spec toast(Phoenix.LiveView.Socket.t(), :info | :error, String.t()) ::
          Phoenix.LiveView.Socket.t()
  def toast(socket, kind, message) do
    _uuid = LiveToast.send_toast(kind, message, duration: @duration)
    socket
  end

  @doc "Classes for each toast: LiveToast's layout and animation hooks, DaisyUI colours."
  @spec toast_class(map()) :: list()
  def toast_class(assigns) do
    [
      "group/toast pointer-events-auto relative z-[100] col-start-1 col-end-1 row-start-1 row-end-2",
      "w-full origin-center items-center justify-between overflow-hidden rounded-box border p-4 shadow-lg",
      # Start hidden while JavaScript sets the toast up.
      "[@media(scripting:enabled)]:opacity-0 [@media(scripting:enabled)]:[[data-phx-main]_&]:opacity-100",
      "flex",
      assigns[:kind] == :info && "border-base-content/10 bg-base-100 text-base-content",
      assigns[:kind] == :error && "border-error/40 bg-base-100 text-error"
    ]
  end
end
