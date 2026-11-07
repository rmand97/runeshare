defmodule RuneshareWeb.StructuredData do
  @moduledoc """
  schema.org JSON-LD for search engines. Pages assign `json_ld` (a list of
  these maps); the root layout encodes them into
  `<script type="application/ld+json">`.
  """

  use RuneshareWeb, :verified_routes

  import RuneshareWeb.PresetComponents, only: [author_name: 1, kind_heading: 1, kind_path: 1]

  @doc "A shared preset as a `CreativeWork` with its likes and copies."
  @spec preset(map()) :: map()
  def preset(preset) do
    %{
      "@context" => "https://schema.org",
      "@type" => "CreativeWork",
      "name" => preset.title,
      "description" => preset.description,
      "url" => url(~p"/presets/#{preset}"),
      "image" => preset.cover_image_url,
      "keywords" => Enum.join(preset.tags, ", "),
      "genre" => kind_heading(preset.kind),
      "about" => %{"@type" => "VideoGame", "name" => "RuneScape 3"},
      "author" => %{
        "@type" => "Person",
        "name" => author_name(preset),
        "url" => url(~p"/u/#{preset.author_id}")
      },
      "version" => preset.version,
      "dateCreated" => DateTime.to_iso8601(preset.inserted_at),
      "dateModified" => DateTime.to_iso8601(preset.updated_at),
      "interactionStatistic" => [
        counter("LikeAction", preset.like_count),
        counter("DownloadAction", preset.copy_count)
      ]
    }
    |> drop_blank()
  end

  @doc "Breadcrumb trail: Home › kind listing › any further `{name, url}` crumbs."
  @spec breadcrumbs(atom(), list({String.t(), String.t()})) :: map()
  def breadcrumbs(kind, crumbs \\ []) do
    trail =
      [
        {"Home", url(~p"/")},
        {kind_heading(kind), unverified_url(RuneshareWeb.Endpoint, kind_path(kind))}
      ] ++
        crumbs

    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" =>
        trail
        |> Enum.with_index(1)
        |> Enum.map(fn {{name, item}, position} ->
          %{"@type" => "ListItem", "position" => position, "name" => name, "item" => item}
        end)
    }
  end

  @doc """
  JSON for inside a `<script>` tag. `<`, `>` and `&` only occur inside JSON
  strings, so swapping them for `\\u` escapes keeps the JSON equal while user
  text can't close the tag.
  """
  @spec encode(list(map())) :: String.t()
  def encode(data) do
    data
    |> JSON.encode!()
    |> String.replace(["<", ">", "&"], fn
      "<" -> "\\u003c"
      ">" -> "\\u003e"
      "&" -> "\\u0026"
    end)
  end

  defp counter(type, count) do
    %{
      "@type" => "InteractionCounter",
      "interactionType" => "https://schema.org/" <> type,
      "userInteractionCount" => count
    }
  end

  defp drop_blank(map), do: Map.reject(map, fn {_key, value} -> value in [nil, ""] end)
end
