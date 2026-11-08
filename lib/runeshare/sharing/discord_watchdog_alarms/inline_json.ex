defmodule Runeshare.Sharing.DiscordWatchdogAlarms.InlineJson do
  @moduledoc """
  Finder: exports pasted straight into the message, anywhere in it, often after a
  line of the poster's own ("With sound and popup: {...}").
  """

  @behaviour Runeshare.Sharing.DiscordWatchdogAlarms.Finder

  alias Runeshare.Sharing.DiscordWatchdogAlarms.CodeBlocks

  @impl true
  def exports(message), do: objects(CodeBlocks.strip(message["content"] || ""))

  @doc "Every top-level `{...}` in `text`, braces inside strings ignored."
  @spec objects(String.t()) :: list(String.t())
  def objects(text), do: objects(text, [])

  defp objects(text, acc) do
    case :binary.match(text, "{") do
      :nomatch ->
        Enum.reverse(acc)

      {start, 1} ->
        rest = binary_part(text, start, byte_size(text) - start)

        case object_length(rest, 0, 0, false, false) do
          {:ok, length} ->
            <<object::binary-size(^length), after_object::binary>> = rest
            objects(after_object, [object | acc])

          :error ->
            objects(binary_part(rest, 1, byte_size(rest) - 1), acc)
        end
    end
  end

  # Bytes up to and including the `}` closing the object `binary` starts with.
  defp object_length(<<>>, _at, _depth, _in_string, _escaped), do: :error

  defp object_length(<<_byte, rest::binary>>, at, depth, true, true),
    do: object_length(rest, at + 1, depth, true, false)

  defp object_length(<<?\\, rest::binary>>, at, depth, true, false),
    do: object_length(rest, at + 1, depth, true, true)

  defp object_length(<<?", rest::binary>>, at, depth, in_string, false),
    do: object_length(rest, at + 1, depth, not in_string, false)

  defp object_length(<<_byte, rest::binary>>, at, depth, true, false),
    do: object_length(rest, at + 1, depth, true, false)

  defp object_length(<<?{, rest::binary>>, at, depth, false, false),
    do: object_length(rest, at + 1, depth + 1, false, false)

  defp object_length(<<?}, _rest::binary>>, at, 1, false, false), do: {:ok, at + 1}

  defp object_length(<<?}, rest::binary>>, at, depth, false, false),
    do: object_length(rest, at + 1, depth - 1, false, false)

  defp object_length(<<_byte, rest::binary>>, at, depth, false, false),
    do: object_length(rest, at + 1, depth, false, false)
end
