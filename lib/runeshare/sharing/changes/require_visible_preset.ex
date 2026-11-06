defmodule Runeshare.Sharing.Changes.RequireVisiblePreset do
  @moduledoc """
  Refuses a create whose `preset_id` points at a preset the actor can't see
  (hidden by a moderator, deleted or made up), so nobody can like or copy it.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    Changeset.before_action(changeset, fn changeset ->
      preset_id = Changeset.get_attribute(changeset, :preset_id)

      case Runeshare.Sharing.get_preset(preset_id, actor: context.actor, load: []) do
        {:ok, _visible} ->
          changeset

        {:error, _not_visible} ->
          Changeset.add_error(changeset, field: :preset_id, message: "preset not found")
      end
    end)
  end
end
