defmodule Runeshare.Sharing.Report.Changes.HidePreset do
  @moduledoc """
  Hides the reported preset in the same transaction that resolves the report,
  so a moderator never ends up with a hidden preset and a report still open (or
  the reverse).
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, report ->
      report = Ash.load!(report, :preset, actor: context.actor)

      case Runeshare.Sharing.hide_preset(report.preset, actor: context.actor) do
        {:ok, preset} -> {:ok, %{report | preset: preset}}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
