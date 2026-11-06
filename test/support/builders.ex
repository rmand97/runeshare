defmodule Runeshare.Test.Builders do
  @moduledoc """
  Shared test data builders. Import in every test module; add a builder here
  once two or more test files need it.
  """

  alias Runeshare.Accounts.User
  alias Runeshare.Sharing

  @doc """
  Signs a user in through the real Google registration action, with fake claims.

  Opts: `:email`, `:name`, `:email_verified` (default `true`).
  """
  @spec register_user!(keyword()) :: User.t()
  def register_user!(opts \\ []) do
    case register_user(opts) do
      {:ok, user} -> user
      {:error, error} -> raise error
    end
  end

  @doc "Like `register_user!/1`, but returns `{:ok, user}` or `{:error, error}`."
  @spec register_user(keyword()) :: {:ok, User.t()} | {:error, term()}
  def register_user(opts \\ []) do
    n = System.unique_integer([:positive])
    email = Keyword.get(opts, :email, "user#{n}@example.com")

    user_info = %{
      "sub" => "google-" <> email,
      "iss" => "https://accounts.google.com",
      "email" => email,
      "email_verified" => Keyword.get(opts, :email_verified, true),
      "name" => Keyword.get(opts, :name, "User #{n}"),
      "picture" => "https://example.com/avatar/#{n}.png"
    }

    User
    |> Ash.Changeset.for_create(
      :register_with_google,
      %{user_info: user_info, oauth_tokens: %{"access_token" => "fake"}},
      context: %{private: %{ash_authentication?: true}}
    )
    |> Ash.create()
  end

  @doc "Signs in an admin (moderator): `admin@example.com` is in the test `:admin_emails`."
  @spec register_admin!() :: User.t()
  def register_admin!, do: register_user!(email: "admin@example.com", name: "Admin")

  @doc "A syntactically valid Tilemarkers export token (`TM2` + base64url)."
  @spec tile_marker_token() :: String.t()
  def tile_marker_token,
    do: "TM2AQxSYWtzaGEgdGlsZXMAAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYn"

  @doc """
  Shares a preset as `author`. Attrs default to a valid Watchdog alarm; for
  `kind: :tile_marker` the content defaults to `tile_marker_token/0`.
  """
  @spec share_preset!(User.t(), map()) :: Sharing.Preset.t()
  def share_preset!(author, attrs \\ %{}) do
    kind = Map.get(attrs, :kind, :watchdog_alarm)

    %{
      kind: kind,
      title: "Vorago rotation timer",
      description: "Pings before each rotation.",
      content: default_content(kind)
    }
    |> Map.merge(attrs)
    |> Sharing.share_preset!(actor: author)
  end

  @doc "A minimal Watchdog export (JSON) containing one alert named `name`."
  @spec watchdog_export(String.t()) :: String.t()
  def watchdog_export(name \\ "Low prayer warning") do
    JSON.encode!(%{
      "schemaVersion" => 1,
      "pluginVersion" => "1.0.0",
      "entries" => [
        %{
          "enabled" => true,
          "kind" => "alert",
          "name" => name,
          "graph" => %{"version" => 1, "nodes" => [], "connections" => []},
          "layout" => []
        }
      ]
    })
  end

  @doc """
  An uploaded image for a preset's `cover_image` argument. Defaults to a real
  640×360 PNG (the seed image); pass `path`/`content_type` for other files.
  """
  @spec cover_image(Path.t(), String.t()) :: Plug.Upload.t()
  def cover_image(path \\ cover_image_path(), content_type \\ "image/png") do
    %Plug.Upload{path: path, filename: Path.basename(path), content_type: content_type}
  end

  @doc "Path of the PNG used by `cover_image/2` (also used by the seeds)."
  @spec cover_image_path() :: Path.t()
  def cover_image_path, do: Application.app_dir(:runeshare, "priv/repo/seed_images/cover.png")

  @doc "Writes `bytes` to a fresh temp file for an upload test and returns its path."
  @spec temp_file!(iodata()) :: Path.t()
  def temp_file!(bytes) do
    path = Path.join(System.tmp_dir!(), "runeshare-#{System.unique_integer([:positive])}")
    File.write!(path, bytes)
    path
  end

  defp default_content(:tile_marker), do: tile_marker_token()
  defp default_content(_kind), do: watchdog_export()
end
