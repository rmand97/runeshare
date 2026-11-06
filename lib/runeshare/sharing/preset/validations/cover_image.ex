defmodule Runeshare.Sharing.Preset.Validations.CoverImage do
  @moduledoc """
  Accepts the `:cover_image` argument only when it really is a JPEG, PNG or WebP
  image (checked from the file's first bytes, not the name or browser-supplied
  type) of at most `max_bytes/0`, and its declared content type matches.
  """

  use Ash.Resource.Validation

  alias Ash.Changeset

  @max_bytes 2_000_000

  @doc "The largest cover image accepted, in bytes. The browser resizes well below this."
  @spec max_bytes() :: pos_integer()
  def max_bytes, do: @max_bytes

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    case Changeset.get_argument(changeset, :cover_image) do
      nil -> :ok
      %Ash.Type.File{} = file -> check(file)
    end
  end

  defp check(file) do
    with {:ok, path} <- Ash.Type.File.path(file),
         {:ok, %{size: size}} when size <= @max_bytes <- File.stat(path),
         {:ok, detected} <- detect(path),
         :ok <- matches_declared(file, detected) do
      :ok
    else
      {:ok, %File.Stat{}} -> error("must be at most 2 MB")
      {:error, :not_an_image} -> error("must be a JPEG, PNG or WebP image")
      {:error, :type_mismatch} -> error("doesn't match its file type")
      {:error, _unreadable} -> error("couldn't be read — please try again")
    end
  end

  @doc "The image type of the file at `path`, from its magic bytes."
  @spec detect(Path.t()) :: {:ok, String.t()} | {:error, :not_an_image | File.posix()}
  def detect(path) do
    case File.open(path, [:read, :binary], &IO.binread(&1, 12)) do
      {:ok, header} -> image_type(header)
      {:error, reason} -> {:error, reason}
    end
  end

  defp image_type(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: {:ok, "image/jpeg"}
  defp image_type(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>), do: {:ok, "image/png"}

  defp image_type(<<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>>),
    do: {:ok, "image/webp"}

  # Anything else, including an empty file (`:eof`).
  defp image_type(_other), do: {:error, :not_an_image}

  # The stored object is served with the declared type, so it has to be the real one.
  defp matches_declared(file, detected) do
    case Ash.Type.File.content_type(file) do
      {:ok, ^detected} -> :ok
      {:ok, _other} -> {:error, :type_mismatch}
      {:error, _none} -> {:error, :type_mismatch}
    end
  end

  defp error(message), do: {:error, field: :cover_image, message: message}
end
