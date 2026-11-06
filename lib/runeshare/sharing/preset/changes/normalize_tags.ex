defmodule Runeshare.Sharing.Preset.Changes.NormalizeTags do
  @moduledoc """
  Lowercases tags, turns inner whitespace into dashes, rewrites known nicknames
  to their standard tag (`TagCatalog`) and drops blanks and repeats, so
  `"Vorago "`, `"VORAGO"` and `"zammy"`/`"Zamorak"` each end up as one tag.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Runeshare.Sharing.TagCatalog

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
    |> Enum.map(&TagCatalog.canonical/1)
    |> Enum.uniq()
  end
end
