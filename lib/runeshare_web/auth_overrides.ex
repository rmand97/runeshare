defmodule RuneshareWeb.AuthOverrides do
  @moduledoc """
  UI overrides for the AshAuthentication sign-in page.
  See https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html
  """

  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
    set :text, "RuneShare"
  end
end
