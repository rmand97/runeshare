defmodule Runeshare.Sharing.Preset.Changes.NormalizeTags do
  @moduledoc """
  Lowercases tags, turns inner whitespace into dashes and drops blanks and repeats,
  so `"Vorago "`, `"vorago"` and `"VORAGO"` are one tag.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    if Changeset.changing_attribute?(changeset, :tags) do
      tags = changeset |> Changeset.get_attribute(:tags) |> List.wrap() |> normalize()
      Changeset.force_change_attribute(changeset, :tags, tags)
    else
      changeset
    end
  end

  @doc "Normalised, de-duplicated tag list."
  @spec normalize(list(String.t())) :: list(String.t())
  def normalize(tags) do
    tags
    |> Enum.map(&(&1 |> String.trim() |> String.downcase() |> String.replace(~r/\s+/, "-")))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end
end
