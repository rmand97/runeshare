defmodule RuneshareWeb.AuthController do
  @moduledoc """
  Callbacks for the Google sign-in flow and sign-out.
  """

  use RuneshareWeb, :controller
  use AshAuthentication.Phoenix.Controller

  require Logger

  @impl AshAuthentication.Phoenix.Controller
  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"
    Logger.info("sign-in ok via #{inspect(activity)} user=#{user.id}", user_id: user.id)

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_flash(:info, "You are now signed in")
    |> redirect(to: return_to)
  end

  @impl AshAuthentication.Phoenix.Controller
  def failure(conn, activity, reason) do
    Logger.warning("sign-in failed via #{inspect(activity)} reason=#{failure_reason(reason)}")

    conn
    |> put_flash(:error, "Google sign-in failed. Please try again.")
    |> redirect(to: ~p"/sign-in")
  end

  @impl AshAuthentication.Phoenix.Controller
  def sign_out(conn, _params) do
    Logger.info("signed out")

    conn
    |> clear_session(:runeshare)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: ~p"/")
  end

  # The error's type and its cause's type only: AshAuthentication errors can carry
  # the OAuth response, tokens and the Google profile.
  defp failure_reason(%{caused_by: %{__struct__: cause}} = reason),
    do: "#{inspect(reason.__struct__)} caused_by=#{inspect(cause)}"

  defp failure_reason(%{__struct__: module}), do: inspect(module)
  defp failure_reason(reason) when is_atom(reason), do: inspect(reason)
  defp failure_reason(_reason), do: "unknown"
end
