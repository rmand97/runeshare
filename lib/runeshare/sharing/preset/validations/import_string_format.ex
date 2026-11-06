defmodule Runeshare.Sharing.Preset.Validations.ImportStringFormat do
  @moduledoc """
  Rejects `content` that isn't an export of the preset's plugin. See `Runeshare.Sharing.ImportString`.
  """

  use Ash.Resource.Validation

  alias Runeshare.Sharing.ImportString

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    kind = Ash.Changeset.get_attribute(changeset, :kind)
    content = Ash.Changeset.get_attribute(changeset, :content)

    if is_atom(kind) and is_binary(content) do
      case ImportString.check(kind, content) do
        :ok -> :ok
        {:error, message} -> {:error, field: :content, message: message}
      end
    else
      :ok
    end
  end

  # Edits submit literal values, so the same in-memory check holds for atomic updates.
  @impl Ash.Resource.Validation
  def atomic(changeset, opts, context), do: validate(changeset, opts, context)
end
