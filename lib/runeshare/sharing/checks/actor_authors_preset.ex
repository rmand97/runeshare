defmodule Runeshare.Sharing.Checks.ActorAuthorsPreset do
  @moduledoc """
  True when the actor wrote the preset a create points at (its `preset_id`).
  Lets a policy refuse, for example, reporting your own preset.
  """

  use Ash.Policy.SimpleCheck

  alias Runeshare.Sharing.Preset

  @impl Ash.Policy.Check
  def describe(_opts), do: "actor is the author of the preset"

  @impl Ash.Policy.SimpleCheck
  def match?(%{id: actor_id} = actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    case Ash.Changeset.get_attribute(changeset, :preset_id) do
      nil -> false
      preset_id -> author_id(preset_id, actor) == actor_id
    end
  end

  def match?(_actor, _context, _opts), do: false

  # Read as the actor: their own presets are always visible to them, even hidden.
  defp author_id(preset_id, actor) do
    case Ash.get(Preset, preset_id, actor: actor) do
      {:ok, preset} -> preset.author_id
      {:error, _not_found} -> nil
    end
  end
end
