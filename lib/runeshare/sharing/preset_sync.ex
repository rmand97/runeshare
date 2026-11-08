defmodule Runeshare.Sharing.PresetSync do
  @moduledoc """
  Mirrors presets from an outside source (the RuneScape Wiki, the Watchdog
  Discord) into one user's shares, matched by title among their presets of
  that kind:

  - a title it hasn't seen is shared (`Sharing.import_preset`, which skips the
    share rate limit),
  - a preset whose content, description or tags changed at the source is edited
    (a new version with the source's change note),
  - everything else is left alone. Presets gone from the source stay.

  A title found more than once gets its creator in brackets. Sources produce
  `t:entry/0` maps and call `sync_as/3` (or `sync/4` in tests).
  """

  alias Runeshare.Accounts
  alias Runeshare.Sharing

  require Logger

  @type entry :: %{
          title: String.t(),
          credit: String.t(),
          description: String.t(),
          content: String.t(),
          tags: list(String.t())
        }

  @type source :: %{
          name: String.t(),
          kind: atom(),
          change_note: String.t(),
          fetch: (-> {:ok, list(entry())} | {:error, term()})
        }

  @type counts :: %{
          created: non_neg_integer(),
          updated: non_neg_integer(),
          unchanged: non_neg_integer(),
          failed: non_neg_integer()
        }

  @doc """
  The user every import is shared as (`config :runeshare, :imports, author_email:`),
  or `nil` when imports are off.
  """
  @spec author_email() :: String.t() | nil
  def author_email, do: Application.get_env(:runeshare, :imports, [])[:author_email]

  @doc """
  Fetches `source` and syncs it as the user with `email`. Logs the outcome; skips
  with a warning if that user hasn't signed in yet or the fetch fails.
  """
  @spec sync_as(String.t(), source()) :: :ok
  def sync_as(email, source) do
    with {:ok, author} <- Accounts.get_user_by_email(email),
         {:ok, entries} <- source.fetch.() do
      counts = sync(author, source.kind, entries, source.change_note)
      Logger.info("#{source.name} synced: #{inspect(counts)}", actor_id: author.id)
    else
      {:error, reason} -> Logger.warning("#{source.name} not synced: #{describe(reason)}")
    end
  end

  @doc "Creates and updates `author`'s `kind` presets to match `entries`."
  @spec sync(Accounts.User.t(), atom(), list(entry()), String.t()) :: counts()
  def sync(author, kind, entries, change_note) do
    existing =
      author.id
      |> Sharing.list_presets_by_author!(actor: author)
      |> Enum.filter(&(&1.kind == kind))
      |> Map.new(&{&1.title, &1})

    counts =
      entries
      |> disambiguate_titles()
      |> Enum.map(&upsert(&1, existing[&1.title], kind, change_note, author))
      |> Enum.frequencies()

    Map.merge(%{created: 0, updated: 0, unchanged: 0, failed: 0}, counts)
  end

  defp upsert(entry, nil, kind, _change_note, author) do
    attrs = entry |> Map.delete(:credit) |> Map.put(:kind, kind)

    case Sharing.import_preset(attrs, actor: author) do
      {:ok, _preset} -> :created
      {:error, error} -> failed(entry, error)
    end
  end

  defp upsert(entry, preset, _kind, change_note, author) do
    changes =
      entry
      |> Map.take([:description, :content, :tags])
      |> Map.update!(:tags, &Sharing.normalize_tags/1)
      |> Enum.reject(fn {field, value} -> Map.get(preset, field) == value end)
      |> Map.new()

    if changes == %{} do
      :unchanged
    else
      case Sharing.edit_preset(preset, Map.put(changes, :change_note, change_note), actor: author) do
        {:ok, _preset} -> :updated
        {:error, error} -> failed(entry, error)
      end
    end
  end

  defp failed(entry, error) do
    Logger.warning("imported preset #{inspect(entry.title)} skipped: #{describe(error)}")
    :failed
  end

  defp describe(%{__exception__: true} = error), do: Exception.message(error)
  defp describe(reason) when is_binary(reason), do: reason
  defp describe(reason), do: inspect(reason)

  @doc "Titles made unique: a repeated title gets its creator in brackets; exact repeats are dropped."
  @spec disambiguate_titles(list(entry())) :: list(entry())
  def disambiguate_titles(entries) do
    counts = Enum.frequencies_by(entries, & &1.title)

    entries
    |> Enum.map(fn entry ->
      if counts[entry.title] > 1,
        do: %{entry | title: String.slice("#{entry.title} (#{entry.credit})", 0, 100)},
        else: entry
    end)
    |> Enum.uniq_by(& &1.title)
  end
end
