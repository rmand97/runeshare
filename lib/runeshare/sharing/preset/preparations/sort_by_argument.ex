defmodule Runeshare.Sharing.Preset.Preparations.SortByArgument do
  @moduledoc """
  Orders a preset listing by its `:sort` argument: `:newest`, `:most_liked` or `:most_copied`.
  """

  use Ash.Resource.Preparation

  alias Ash.Query

  @impl Ash.Resource.Preparation
  def prepare(query, _opts, _context) do
    case Query.get_argument(query, :sort) do
      :most_liked -> Query.sort(query, like_count: :desc, inserted_at: :desc)
      :most_copied -> Query.sort(query, copy_count: :desc, inserted_at: :desc)
      _newest -> Query.sort(query, inserted_at: :desc)
    end
  end
end
