defmodule RuneshareWeb.AuthController do
  @moduledoc """
  Callbacks for the Google sign-in flow and sign-out.
  """

  use RuneshareWeb, :controller
  use AshAuthentication.Phoenix.Controller

  @impl AshAuthentication.Phoenix.Controller
  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_flash(:info, "You are now signed in")
    |> redirect(to: return_to)
  end

  @impl AshAuthentication.Phoenix.Controller
  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Google sign-in failed. Please try again.")
    |> redirect(to: ~p"/sign-in")
  end

  @impl AshAuthentication.Phoenix.Controller
  def sign_out(conn, _params) do
    conn
    |> clear_session(:runeshare)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: ~p"/")
  end
end
