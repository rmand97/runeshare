defmodule Runeshare.Sharing.Comment.Changes.StampPresetVersion do
  @moduledoc """
  Records which version of the preset was current when the comment was posted,
  so readers can tell a comment refers to an older version.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    Changeset.before_action(changeset, fn changeset ->
      preset_id = Changeset.get_attribute(changeset, :preset_id)

      case Runeshare.Sharing.get_preset(preset_id, actor: context.actor, load: []) do
        {:ok, preset} ->
          Changeset.force_change_attribute(changeset, :preset_version, preset.version)

        {:error, _not_visible} ->
          Changeset.add_error(changeset, field: :preset_id, message: "preset not found")
      end
    end)
  end
end
