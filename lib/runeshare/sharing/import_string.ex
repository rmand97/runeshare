defmodule Runeshare.Sharing.ImportString do
  @moduledoc """
  Recognises the export formats of the RS3 plugins presets are shared for.

  - **Tilemarkers**: `TM2` followed by unpadded base64url (RS Wiki, Guide:Tilemarkers).
    The decoded payload starts with a version byte, a name-length byte and the UTF-8
    preset name.
  - **Watchdog**: a JSON document `{"schemaVersion", "pluginVersion", "entries"}`
    where every entry has a `name` and a node `graph`.
  """

  @tile_marker ~r/\ATM2[A-Za-z0-9_-]{16,}\z/

  @doc "`:ok`, or `{:error, message}` explaining why `content` isn't a `kind` export."
  @spec check(atom(), String.t()) :: :ok | {:error, String.t()}
  def check(:tile_marker, content) do
    if Regex.match?(@tile_marker, content),
      do: :ok,
      else:
        {:error,
         "doesn't look like a Tilemarkers token — export it from the plugin's Presets tab; it starts with TM2"}
  end

  def check(:watchdog_alarm, content) do
    case watchdog_entries(content) do
      {:ok, _entries} ->
        :ok

      :error ->
        {:error,
         ~s(doesn't look like a Watchdog export — paste the whole JSON, starting with {"schemaVersion")}
    end
  end

  # Unknown kinds are rejected by the `kind` attribute's own constraint.
  def check(_kind, _content), do: :ok

  @doc "Names of the alerts in a Watchdog export, or `[]` when it isn't one."
  @spec watchdog_names(String.t()) :: list(String.t())
  def watchdog_names(content) do
    case watchdog_entries(content) do
      {:ok, entries} -> Enum.map(entries, & &1["name"])
      :error -> []
    end
  end

  @doc """
  Plain-language outline of each alert in a Watchdog export: its name, what
  triggers it, and what it does. Empty when `content` isn't a Watchdog export.

      [%{name: "Mining - fatigue test", triggers: ["XP drop"], actions: ["Sound", "Screen flash"]}]
  """
  @spec watchdog_summary(String.t()) ::
          list(%{name: String.t(), triggers: list(String.t()), actions: list(String.t())})
  def watchdog_summary(content) do
    case watchdog_entries(content) do
      {:ok, entries} -> Enum.map(entries, &summarize_entry/1)
      :error -> []
    end
  end

  @doc "A title taken from the export itself, or `nil` when none can be read."
  @spec suggested_title(atom(), String.t()) :: String.t() | nil
  def suggested_title(:watchdog_alarm, content), do: List.first(watchdog_names(content))

  def suggested_title(:tile_marker, "TM2" <> encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, <<_version, length, name::binary-size(length), _rest::binary>>} -> readable_name(name)
      {:ok, _too_short} -> nil
      :error -> nil
    end
  end

  def suggested_title(_kind, _content), do: nil

  defp readable_name(name) do
    if String.valid?(name) do
      trimmed = String.trim(name)
      if trimmed != "", do: trimmed
    end
  end

  defp watchdog_entries(content) do
    case JSON.decode(content) do
      {:ok, %{"schemaVersion" => version, "entries" => [_first | _rest] = entries}}
      when is_integer(version) ->
        if Enum.all?(entries, &watchdog_entry?/1), do: {:ok, entries}, else: :error

      {:ok, _other_shape} ->
        :error

      {:error, _reason} ->
        :error
    end
  end

  defp watchdog_entry?(%{"name" => name, "graph" => %{}}) when is_binary(name), do: true
  defp watchdog_entry?(_entry), do: false

  defp summarize_entry(%{"name" => name, "graph" => graph}) do
    types = graph |> Map.get("nodes", []) |> List.wrap() |> Enum.map(&node_type/1)

    %{
      name: name,
      triggers: labels(types, "trigger."),
      actions: labels(types, "action.")
    }
  end

  defp node_type(%{"type" => type}) when is_binary(type), do: type
  defp node_type(_node), do: ""

  defp labels(types, prefix) do
    for "" <> type <- types, String.starts_with?(type, prefix), uniq: true do
      type |> String.replace_prefix(prefix, "") |> humanize()
    end
  end

  # "xp_drop" -> "XP drop", "screen_flash" -> "Screen flash"
  defp humanize(slug) do
    case String.split(slug, "_", trim: true) do
      [first | rest] -> Enum.join([upcase_word(first) | rest], " ")
      [] -> slug
    end
  end

  defp upcase_word(word) when word in ["xp", "hp", "npc", "ge"], do: String.upcase(word)
  defp upcase_word(word), do: String.capitalize(word)
end
