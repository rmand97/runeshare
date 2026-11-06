defmodule RuneshareWeb.LiveUserAuth do
  @moduledoc """
  `on_mount` hooks that gate LiveViews on whether a user is signed in.

  Public pages (`:live_user_optional`) also get `@visitor`: who is looking, as a
  stable key — `"user:<id>"` when signed in, else `"anon:<session visitor id>"`.
  """

  use RuneshareWeb, :verified_routes

  import Phoenix.Component

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)
    {:cont, assign(socket, :visitor, visitor(socket.assigns.current_user, session))}
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp visitor(%{id: id}, _session), do: "user:" <> id
  defp visitor(nil, %{"visitor_id" => id}), do: "anon:" <> id
  defp visitor(nil, _session), do: nil
end
