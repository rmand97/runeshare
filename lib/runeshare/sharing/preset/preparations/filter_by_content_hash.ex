defmodule Runeshare.Sharing.Preset.Preparations.FilterByContentHash do
  @moduledoc """
  Narrows a query to presets whose `content_hash` matches the `:content` argument.
  """

  use Ash.Resource.Preparation

  alias Runeshare.Sharing.Preset.Changes.HashContent

  require Ash.Query

  @impl Ash.Resource.Preparation
  def prepare(query, _opts, _context) do
    hash = query |> Ash.Query.get_argument(:content) |> HashContent.hash()
    Ash.Query.filter(query, content_hash == ^hash)
  end
end
