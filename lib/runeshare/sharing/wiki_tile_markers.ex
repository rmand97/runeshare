defmodule Runeshare.Sharing.WikiTileMarkers do
  @moduledoc """
  Keeps the tile marker presets from the RuneScape Wiki's
  [Guide:Tilemarkers](https://runescape.wiki/w/Guide:Tilemarkers) on RuneShare,
  shared by one configured user.

  `sync/1` fetches the page's wikitext, reads every table row (location, author,
  `TM2` token) and, matched by title among that user's tile marker presets:

  - shares a preset for a row it hasn't seen (`Sharing.import_preset`, which skips
    the share rate limit),
  - edits the preset when the wiki's token, notes or section changed (a new
    version, change note "Synced from the RuneScape Wiki"),
  - leaves everything else alone. Presets removed from the wiki stay.

  Runs at boot when `config :runeshare, :wiki_tile_markers, author_email: ...` is
  set (prod, see `config/runtime.exs`), and from `priv/repo/seeds.exs`.
  """

  alias Runeshare.Accounts
  alias Runeshare.Sharing

  require Logger

  @page_url "https://runescape.wiki/w/Guide:Tilemarkers"
  @raw_url @page_url <> "?action=raw"
  @change_note "Synced from the RuneScape Wiki"

  @type entry :: %{
          title: String.t(),
          description: String.t(),
          content: String.t(),
          tags: list(String.t())
        }

  @doc "Syncs at boot if an author email is configured; a no-op otherwise."
  @spec sync_on_boot() :: :ok
  def sync_on_boot do
    case Application.get_env(:runeshare, :wiki_tile_markers, [])[:author_email] do
      nil -> :ok
      email -> sync_as(email)
    end
  end

  @doc "Syncs as the user with `email`. Logs and skips if they haven't signed in yet."
  @spec sync_as(String.t()) :: :ok
  def sync_as(email) do
    with {:ok, author} <- Accounts.get_user_by_email(email),
         {:ok, wikitext} <- fetch() do
      counts = sync(author, wikitext)
      Logger.info("wiki tile markers synced: #{inspect(counts)}", actor_id: author.id)
    else
      {:error, reason} -> Logger.warning("wiki tile markers not synced: #{describe(reason)}")
    end
  end

  @doc "Fetches the guide's wikitext."
  @spec fetch() :: {:ok, String.t()} | {:error, term()}
  def fetch do
    options = Application.get_env(:runeshare, :wiki_tile_markers_req_options, [])

    case Req.get(@raw_url, [headers: [user_agent: "RuneShare (https://runeshare.dk)"]] ++ options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, "wiki answered HTTP #{status}"}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Creates and updates `author`'s presets to match `wikitext`. Returns how many
  presets were created, updated, left unchanged or failed.
  """
  @spec sync(Accounts.User.t(), String.t()) :: %{atom() => non_neg_integer()}
  def sync(author, wikitext) do
    existing =
      author.id
      |> Sharing.list_presets_by_author!(actor: author)
      |> Enum.filter(&(&1.kind == :tile_marker))
      |> Map.new(&{&1.title, &1})

    counts =
      wikitext
      |> parse()
      |> Enum.map(&upsert(&1, existing[&1.title], author))
      |> Enum.frequencies()

    Map.merge(%{created: 0, updated: 0, unchanged: 0, failed: 0}, counts)
  end

  defp upsert(entry, nil, author) do
    case Sharing.import_preset(Map.put(entry, :kind, :tile_marker), actor: author) do
      {:ok, _preset} -> :created
      {:error, error} -> failed(entry, error)
    end
  end

  defp upsert(entry, preset, author) do
    changes =
      entry
      |> Map.take([:description, :content, :tags])
      |> Map.update!(:tags, &Sharing.normalize_tags/1)
      |> Enum.reject(fn {field, value} -> Map.get(preset, field) == value end)
      |> Map.new()

    if changes == %{} do
      :unchanged
    else
      case Sharing.edit_preset(preset, Map.put(changes, :change_note, @change_note),
             actor: author
           ) do
        {:ok, _preset} -> :updated
        {:error, error} -> failed(entry, error)
      end
    end
  end

  defp failed(entry, error) do
    Logger.warning("wiki tile marker #{inspect(entry.title)} skipped: #{describe(error)}")
    :failed
  end

  defp describe(%{__exception__: true} = error), do: Exception.message(error)
  defp describe(reason), do: inspect(reason)

  @doc """
  Every preset on the guide page: one per table row with a valid `TM2` token.
  Titles are the row's location; a location listed more than once gets its
  author in brackets.
  """
  @spec parse(String.t()) :: list(entry())
  def parse(wikitext) do
    wikitext
    |> String.split("\n")
    |> Enum.reduce(%{h2: nil, h3: nil, row: nil, rows: []}, &read_line/2)
    |> finish_row()
    |> Map.fetch!(:rows)
    |> Enum.reverse()
    |> Enum.flat_map(&to_entry/1)
    |> disambiguate_titles()
  end

  defp read_line(line, state), do: read(classify(line), state)

  defp classify(line) do
    cond do
      heading = heading(line, "===") -> {:h3, heading}
      heading = heading(line, "==") -> {:h2, heading}
      String.starts_with?(line, ["|-", "|}", "{|"]) -> :row_break
      String.starts_with?(line, "!") -> :column_header
      String.starts_with?(line, "|") -> {:cell, String.slice(line, 1..-1//1)}
      true -> {:text, line}
    end
  end

  defp read({:h3, heading}, state), do: %{finish_row(state) | h3: heading}
  defp read({:h2, heading}, state), do: %{finish_row(state) | h2: heading, h3: nil}
  defp read(:row_break, state), do: finish_row(state)
  defp read(:column_header, state), do: state

  # Cells are collected newest first; finish_row/1 puts them in order.
  defp read({:cell, text}, %{row: nil} = state),
    do: %{state | row: %{h2: state.h2, h3: state.h3, cells: [text]}}

  defp read({:cell, text}, %{row: row} = state),
    do: %{state | row: %{row | cells: [text | row.cells]}}

  # A cell's text can run over several lines.
  defp read({:text, line}, %{row: %{cells: [last | cells]} = row} = state),
    do: %{state | row: %{row | cells: [last <> "\n" <> line | cells]}}

  defp read({:text, _line}, state), do: state

  defp heading(line, marks) do
    case Regex.run(~r/\A#{marks}\s*([^=].*?)\s*#{marks}\s*\z/, line) do
      [_match, heading] -> heading
      nil -> nil
    end
  end

  defp finish_row(%{row: nil} = state), do: state

  defp finish_row(%{row: row} = state),
    do: %{state | row: nil, rows: [%{row | cells: Enum.reverse(row.cells)} | state.rows]}

  # Some rows carry an extra column before the preview, so look in every later cell.
  defp to_entry(%{cells: [location, author | rest]} = row) do
    with [_match, token] <- Regex.run(~r/token=\s*(TM2[A-Za-z0-9_-]+)/, Enum.join(rest)),
         :ok <- Sharing.check_import_string(:tile_marker, token),
         [title | notes] <- location |> plain_text() |> String.split("\n", parts: 2) do
      author =
        case plain_text(author) do
          "" -> "an unknown author"
          name -> name
        end

      [
        %{
          title: title |> String.trim() |> String.slice(0, 100),
          author: author,
          description: description(author, Enum.join(notes)),
          content: token,
          tags: tags(row.h2, row.h3)
        }
      ]
    else
      nil -> []
      {:error, _reason} -> []
    end
  end

  defp to_entry(_row), do: []

  defp description(author, notes) do
    credit =
      "Created by #{author}. From the RuneScape Wiki's Guide:Tilemarkers " <>
        "(#{@page_url}), CC BY-NC-SA 3.0."

    notes = String.trim(notes)
    room = 2000 - String.length(credit) - 2

    if notes == "",
      do: credit,
      else: credit <> "\n\n" <> String.slice(notes, 0, room)
  end

  # "Amascut, the Devourer" -> "amascut"; "Skilling bosses" -> "skilling".
  defp tags(h2, h3) do
    group =
      cond do
        h2 =~ ~r/pvm/i -> ["pvm"]
        h2 =~ ~r/skilling/i -> ["skilling"]
        true -> []
      end

    section =
      if h3 && h3 != h2,
        do: [h3 |> String.split(",") |> hd() |> String.replace(~r/\Athe\s+/i, "")],
        else: []

    [section, group, ["rs-wiki"]]
    |> Enum.concat()
    |> Enum.map(&String.slice(&1, 0, 24))
    |> Sharing.normalize_tags()
  end

  defp disambiguate_titles(entries) do
    counts = Enum.frequencies_by(entries, & &1.title)

    entries
    |> Enum.map(fn entry ->
      title =
        if counts[entry.title] > 1,
          do: "#{entry.title} (#{entry.author})",
          else: entry.title

      %{entry | title: title}
    end)
    |> Enum.uniq_by(& &1.title)
    |> Enum.map(&Map.delete(&1, :author))
  end

  # Wikitext to the plain text a user would read: links and formatting
  # unwrapped, templates and HTML tags dropped.
  defp plain_text(wikitext) do
    wikitext
    |> String.replace(~r/<br\s*\/?>/i, "\n")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\{\{[^{}]*\}\}/, "")
    |> String.replace(~r/\[\[(?:[^|\]]*\|)?([^\]]*)\]\]/, "\\1")
    |> String.replace(~r/\[https?:\/\/\S+\s+([^\]]+)\]/, "\\1")
    |> String.replace(~r/'{2,}/, "")
    |> String.replace(~r/[ \t]+\n/, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end
