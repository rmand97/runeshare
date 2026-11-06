defmodule Runeshare.Sharing.Preset.Changes.SnapshotVersion do
  @moduledoc """
  Bumps the preset's `version` (1 on share) and records a `PresetVersion` snapshot
  of the resulting title, description and content. An edit that changes none of
  those and has no change note (only tags, or nothing at all) keeps the current version.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @versioned [:title, :description, :content]

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    if new_version?(changeset), do: snapshot(changeset), else: changeset
  end

  @doc "Whether saving `changeset` (a share or an edit) creates a new version."
  @spec new_version?(Changeset.t()) :: boolean()
  def new_version?(%Changeset{action_type: :create}), do: true

  def new_version?(changeset) do
    change_note(changeset) not in [nil, ""] or
      Enum.any?(@versioned, &Changeset.changing_attribute?(changeset, &1))
  end

  defp snapshot(changeset) do
    number =
      case changeset.action_type do
        :create -> 1
        :update -> changeset.data.version + 1
      end

    snapshot =
      @versioned
      |> Map.new(&{&1, Changeset.get_attribute(changeset, &1)})
      |> Map.put(:number, number)
      |> Map.put(:note, change_note(changeset))

    changeset
    |> Changeset.force_change_attribute(:version, number)
    |> Changeset.manage_relationship(:versions, [snapshot],
      type: :create,
      on_lookup: :ignore
    )
  end

  defp change_note(changeset) do
    if Enum.any?(changeset.action.arguments, &(&1.name == :change_note)),
      do: Changeset.get_argument(changeset, :change_note)
  end
end
