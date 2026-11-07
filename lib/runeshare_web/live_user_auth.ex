defmodule RuneshareWeb.LiveUserAuth do
  @moduledoc """
  `on_mount` hooks that gate LiveViews on whether a user is signed in.

  Public pages (`:live_user_optional`) also get `@visitor`: who is looking, as a
  stable key — `"user:<id>"` when signed in, else `"anon:<session visitor id>"`.

  Every hook also tags the LiveView process's log lines: `live_view`, `user_id`
  (never the email) and, while an event is handled, `event`.
  """

  use RuneshareWeb, :verified_routes

  import Phoenix.Component

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = socket |> assign_new(:current_user, fn -> nil end) |> tag_logs()
    {:cont, assign(socket, :visitor, visitor(socket.assigns.current_user, session))}
  end

  # Pages behind sign-in (and the sign-in page itself) are kept out of search engines.
  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket |> assign(:noindex, true) |> tag_logs()}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket |> assign(current_user: nil, noindex: true) |> tag_logs()}
    end
  end

  defp tag_logs(socket) do
    Logger.metadata(
      live_view: inspect(socket.view),
      user_id: socket.assigns[:current_user] && socket.assigns.current_user.id
    )

    socket
    |> Phoenix.LiveView.attach_hook(:log_event, :handle_event, &tag_event/3)
    |> Phoenix.LiveView.attach_hook(:log_event_done, :after_render, &untag_event/1)
  end

  defp tag_event(event, _params, socket) do
    Logger.metadata(event: event)
    {:cont, socket}
  end

  defp untag_event(socket) do
    Logger.metadata(event: nil)
    socket
  end

  defp visitor(%{id: id}, _session), do: "user:" <> id
  defp visitor(nil, %{"visitor_id" => id}), do: "anon:" <> id
  defp visitor(nil, _session), do: nil
end
