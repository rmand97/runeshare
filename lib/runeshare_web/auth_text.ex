defmodule RuneshareWeb.AuthText do
  @moduledoc """
  `gettext_fn` for the AshAuthentication sign-in page. It builds button labels
  from strategy names ("Sign in with Github"); this fixes the brand spelling and
  passes every other text through unchanged.
  """

  alias AshAuthentication.Phoenix.Web

  @spec translate(String.t(), keyword() | map()) :: String.t()
  def translate(msgid, bindings) do
    # The library's own handling (no gettext_fn) fills in %{placeholders}.
    Web.gettext_switch(
      nil,
      String.replace(msgid, "Github", "GitHub"),
      bindings
    )
  end
end
