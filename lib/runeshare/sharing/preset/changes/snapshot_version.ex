defmodule Runeshare.Sharing.Preset.Changes.SnapshotVersion do
  @moduledoc """
  Records a `PresetVersion` snapshot of the resulting title, description and
  content, and keeps the preset's `version` pointing at the newest one.

  - Sharing creates v1.
  - An edit that changes none of those and has no change note (only tags, or
    nothing at all) keeps the current version.
  - An edit within `merge_window/0` of the newest version's creation updates
    that version in place (a typo fix right after saving doesn't add v3, v4, v5).
  - Any other edit adds the next version.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Runeshare.Sharing

  @versioned [:title, :description, :content]

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    cond do
      not new_version?(changeset) -> changeset
      changeset.action_type == :create -> add_version(changeset, 1)
      true -> Changeset.before_action(changeset, &snapshot_edit(&1, context.actor))
    end
  end

  @doc "Whether saving `changeset` (a share or an edit) records a version (new or updated)."
  @spec new_version?(Changeset.t()) :: boolean()
  def new_version?(%Changeset{action_type: :create}), do: true

  def new_version?(changeset) do
    change_note(changeset) not in [nil, ""] or
      Enum.any?(@versioned, &Changeset.changing_attribute?(changeset, &1))
  end

  @doc "Seconds after a version is created during which an edit updates it instead."
  @spec merge_window() :: non_neg_integer()
  def merge_window, do: Application.get_env(:runeshare, :version_merge_window_seconds, 0)

  @doc "Whether an edit saved at `now` would update `version` rather than add a new one."
  @spec amends?(Sharing.PresetVersion.t(), DateTime.t()) :: boolean()
  def amends?(version, now \\ DateTime.utc_now()),
    do: DateTime.diff(now, version.inserted_at) < merge_window()

  defp snapshot_edit(changeset, actor) do
    preset = changeset.data

    case Sharing.get_preset_version(preset.id, preset.version, actor: actor) do
      {:ok, newest} ->
        if amends?(newest),
          do: amend_version(changeset, newest),
          else: add_version(changeset, preset.version + 1)

      {:error, _missing} ->
        add_version(changeset, preset.version + 1)
    end
  end

  defp add_version(changeset, number) do
    snapshot =
      changeset
      |> snapshot_fields()
      |> Map.put(:number, number)
      |> Map.put(:note, change_note(changeset))

    changeset
    |> Changeset.force_change_attribute(:version, number)
    |> Changeset.manage_relationship(:versions, [snapshot], type: :create, on_lookup: :ignore)
  end

  # Same number; a new note replaces the old one, no note keeps it.
  defp amend_version(changeset, newest) do
    snapshot =
      changeset
      |> snapshot_fields()
      |> Map.merge(%{id: newest.id, note: change_note(changeset) || newest.note})

    Changeset.manage_relationship(changeset, :versions, [snapshot],
      on_lookup: :ignore,
      on_match: {:update, :amend},
      on_no_match: :error,
      on_missing: :ignore
    )
  end

  defp snapshot_fields(changeset),
    do: Map.new(@versioned, &{&1, Changeset.get_attribute(changeset, &1)})

  defp change_note(changeset) do
    if Enum.any?(changeset.action.arguments, &(&1.name == :change_note)) do
      case Changeset.get_argument(changeset, :change_note) do
        "" -> nil
        note -> note
      end
    end
  end
end
