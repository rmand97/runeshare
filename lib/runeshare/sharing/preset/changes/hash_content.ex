defmodule Runeshare.Sharing.Preset.Changes.HashContent do
  @moduledoc """
  Keeps `content_hash` (SHA-256, hex) in step with `content`.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Changeset.get_attribute(changeset, :content) do
      content when is_binary(content) ->
        Changeset.force_change_attribute(changeset, :content_hash, hash(content))

      _missing ->
        changeset
    end
  end

  @doc "The hash stored for `content`."
  @spec hash(String.t()) :: String.t()
  def hash(content),
    do: :sha256 |> :crypto.hash(String.trim(content)) |> Base.encode16(case: :lower)
end
