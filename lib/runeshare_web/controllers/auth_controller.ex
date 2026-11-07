defmodule RuneshareWeb.AuthController do
  @moduledoc """
  Callbacks for the Google sign-in flow and sign-out.
  """

  use RuneshareWeb, :controller
  use AshAuthentication.Phoenix.Controller

  require Logger

  @providers %{google: "Google", github: "GitHub", discord: "Discord", twitch: "Twitch"}

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
    |> put_flash(:error, failure_message(activity, reason))
    |> redirect(to: ~p"/sign-in")
  end

  # `activity` is `{strategy, phase}`, e.g. `{:discord, :callback}`.
  defp failure_message({strategy, _phase}, reason) when is_map_key(@providers, strategy) do
    provider = @providers[strategy]

    if unverified_email?(reason),
      do: "#{provider} hasn't verified your email address. Verify it there, then try again.",
      else: "#{provider} sign-in failed. Please try again."
  end

  defp failure_message(_activity, _reason), do: "Sign-in failed. Please try again."

  # ApplyOAuthProfile refuses unverified emails with this message.
  defp unverified_email?(reason) when is_exception(reason),
    do: Exception.message(reason) =~ "hasn't verified this account's email"

  defp unverified_email?(_reason), do: false

  @impl AshAuthentication.Phoenix.Controller
  def sign_out(conn, _params) do
    Logger.info("signed out")

    conn
    |> clear_session(:runeshare)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: ~p"/")
  end

  # The error's type and its cause's type only: AshAuthentication errors can carry
  # the OAuth response, tokens and the provider's profile.
  defp failure_reason(%{caused_by: %{__struct__: cause}} = reason),
    do: "#{inspect(reason.__struct__)} caused_by=#{inspect(cause)}"

  defp failure_reason(%{__struct__: module}), do: inspect(module)
  defp failure_reason(reason) when is_atom(reason), do: inspect(reason)
  defp failure_reason(_reason), do: "unknown"
end
