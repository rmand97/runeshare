defmodule Runeshare.Sharing.TileMarkerCodec do
  @moduledoc """
  Decodes a Tilemarkers `TM2` preset token into its name and tiles, for the map
  on a tile marker preset's page.

  A port of the plugin's own codec (`preset_codec.lua` in
  [PrettyRS/tilemarkers](https://github.com/PrettyRS/tilemarkers), BSD 3-Clause,
  Copyright (c) 2026 PrettyRS), by way of the RuneScape Wiki's Module:Tilemarkers.

  After `TM2`, unpadded base64url of:

  - a flags byte: low 4 bits = which planes (0–3) have tiles, `0x10` labels in a
    dictionary, `0x20` Morton-coded coordinates, `0x40` prefix-compressed dictionary
  - the preset name (varuint length + UTF-8)
  - per plane: a tile count, then coordinates (zigzag start + delta codes, or
    Morton codes)
  - a style table (outline RGBA, fill RGBA, flags, thickness)
  - per tile: style index and whether it has a label
  - the labels, inline or through the dictionary

  Every reader below returns `{:ok, value, rest}` or `:error`.
  """

  import Bitwise

  @max_tiles 100_000
  @max_name_bytes 128
  @max_label_bytes 128
  @dictionary 0x10
  @morton 0x20
  @prefix_dictionary 0x40
  @max_morton 0x0FFFFFFF

  @typedoc "Colours are `#rrggbb`; alphas 0–255."
  @type tile :: %{
          x: integer(),
          z: integer(),
          plane: 0..3,
          outline: String.t(),
          outline_alpha: 0..255,
          fill: String.t(),
          fill_alpha: 0..255,
          filled: boolean(),
          label: String.t() | nil
        }

  @doc "`{:ok, %{name:, tiles:}}` for a valid token, `:error` otherwise."
  @spec decode(String.t()) :: {:ok, %{name: String.t(), tiles: list(tile())}} | :error
  def decode("TM2" <> encoded) do
    with {:ok, binary} <- Base.url_decode64(encoded, padding: false),
         {:ok, flags, rest} <- header(binary),
         {:ok, name, rest} <- string(rest, 0, @max_name_bytes),
         {:ok, tiles, rest} <- planes(rest, flags),
         {:ok, styles, rest} <- styles(rest, Enum.count(tiles)),
         {:ok, tiles, rest} <- apply_styles(rest, tiles, styles),
         {:ok, tiles, ""} <- labels(rest, tiles, flags) do
      {:ok, %{name: name, tiles: tiles}}
    else
      {:ok, _tiles, _trailing_bytes} -> :error
      :error -> :error
    end
  end

  def decode(_content), do: :error

  @doc "The tiles of a valid token, `[]` otherwise."
  @spec tiles(String.t()) :: list(tile())
  def tiles(content) do
    case decode(content) do
      {:ok, %{tiles: tiles}} -> tiles
      :error -> []
    end
  end

  defp header(<<flags, rest::binary>>)
       when (flags &&& 0x80) == 0 and
              ((flags &&& @prefix_dictionary) == 0 or (flags &&& @dictionary) != 0),
       do: {:ok, flags, rest}

  defp header(_binary), do: :error

  # Tiles per plane, in plane order.
  defp planes(binary, flags) do
    0..3
    |> Enum.filter(&((flags &&& 1 <<< &1) != 0))
    |> read_each(binary, fn plane, rest, earlier ->
      plane_tiles(rest, plane, earlier |> List.flatten() |> Enum.count(), flags)
    end)
    |> case do
      {:ok, per_plane, rest} -> {:ok, List.flatten(per_plane), rest}
      :error -> :error
    end
  end

  defp plane_tiles(binary, plane, seen, flags) do
    case bounded_varuint(binary, 1, @max_tiles - seen) do
      {:ok, count, rest} when (flags &&& @morton) != 0 -> morton_tiles(rest, plane, count)
      {:ok, count, rest} -> delta_tiles(rest, plane, count)
      :error -> :error
    end
  end

  defp delta_tiles(binary, plane, count) do
    case varuint_pair(binary) do
      {:ok, {x, z}, rest} ->
        first = %{x: zigzag(x), z: zigzag(z), plane: plane}
        next_deltas(rest, first, count - 1, [first])

      :error ->
        :error
    end
  end

  defp next_deltas(rest, _last, 0, acc), do: {:ok, Enum.reverse(acc), rest}

  defp next_deltas(binary, last, left, acc) do
    case delta(binary) do
      {:ok, {dx, dz}, rest} ->
        tile = %{last | x: last.x + dx, z: last.z + dz}
        next_deltas(rest, tile, left - 1, [tile | acc])

      :error ->
        :error
    end
  end

  # One step to the next tile: north along the column, one column east, or a jump.
  defp delta(<<code, rest::binary>>) when code < 0x80, do: {:ok, {0, code + 1}, rest}
  defp delta(<<code, rest::binary>>) when code < 0xC0, do: {:ok, {1, code - 0xA0}, rest}

  defp delta(<<0xC0, rest::binary>>) do
    case varuint_pair(rest) do
      {:ok, {dx, dz}, rest} -> {:ok, {dx, zigzag(dz)}, rest}
      :error -> :error
    end
  end

  defp delta(_binary), do: :error

  defp morton_tiles(binary, plane, count) do
    case bounded_varuint(binary, 0, @max_morton) do
      {:ok, code, rest} -> next_mortons(rest, code, plane, count - 1, [morton_tile(code, plane)])
      :error -> :error
    end
  end

  defp next_mortons(rest, _code, _plane, 0, acc), do: {:ok, Enum.reverse(acc), rest}

  defp next_mortons(binary, code, plane, left, acc) do
    case bounded_varuint(binary, 0, @max_morton - code) do
      {:ok, step, rest} ->
        next_mortons(rest, code + step, plane, left - 1, [morton_tile(code + step, plane) | acc])

      :error ->
        :error
    end
  end

  # Interleaved bits: z in the even positions, x in the odd ones.
  defp morton_tile(code, plane) do
    {x, z} =
      Enum.reduce(0..13, {0, 0}, fn bit, {x, z} ->
        {x ||| (code >>> (bit * 2 + 1) &&& 1) <<< bit, z ||| (code >>> (bit * 2) &&& 1) <<< bit}
      end)

    %{x: x, z: z, plane: plane}
  end

  # A token with tiles has at least one style, and never more styles than tiles.
  defp styles(binary, tile_count) do
    case bounded_varuint(binary, min(tile_count, 1), tile_count) do
      {:ok, count, rest} -> read_styles(rest, count, [])
      :error -> :error
    end
  end

  defp read_styles(rest, 0, acc), do: {:ok, acc |> Enum.reverse() |> List.to_tuple(), rest}

  defp read_styles(<<outline::32, fill::32, flags, thickness, rest::binary>>, left, acc)
       when (flags &&& 0xF0) == 0 and (flags &&& 0x05) != 0x05 and (flags &&& 0x0A) != 0x0A and
              thickness <= 100 do
    style = %{
      outline: rgb(outline),
      outline_alpha: outline &&& 0xFF,
      fill: rgb(fill),
      fill_alpha: fill &&& 0xFF,
      # 0x04 = "plugin default" (filled); otherwise bit 0 says whether to fill.
      filled: (flags &&& 0x04) != 0 or (flags &&& 0x01) != 0
    }

    read_styles(rest, left - 1, [style | acc])
  end

  defp read_styles(_binary, _left, _acc), do: :error

  # Colours are RGBA, as the wiki's map reads them.
  defp rgb(rgba) do
    hex = (rgba >>> 8) |> Integer.to_string(16) |> String.pad_leading(6, "0")
    "#" <> String.downcase(hex)
  end

  # Each tile's style, and whether a label follows for it.
  defp apply_styles(binary, tiles, styles) do
    read_each(tiles, binary, fn tile, rest, _acc ->
      case bounded_varuint(rest, 0, tuple_size(styles) * 2 - 1) do
        {:ok, meta, rest} ->
          styled =
            tile |> Map.merge(elem(styles, meta >>> 1)) |> Map.put(:label, (meta &&& 1) == 1)

          {:ok, styled, rest}

        :error ->
          :error
      end
    end)
  end

  defp labels(binary, tiles, flags) do
    labelled = Enum.count(tiles, & &1.label)

    result =
      if (flags &&& @dictionary) != 0,
        do: dictionary_labels(binary, labelled, (flags &&& @prefix_dictionary) != 0),
        else: read_n(binary, labelled, &string(&1, 1, @max_label_bytes))

    case result do
      {:ok, labels, rest} -> {:ok, attach_labels(tiles, labels), rest}
      :error -> :error
    end
  end

  defp dictionary_labels(binary, labelled, prefixed?) do
    case bounded_varuint(binary, 1, labelled) do
      {:ok, count, rest} -> dictionary_entries(rest, count, labelled, prefixed?)
      :error -> :error
    end
  end

  defp dictionary_entries(binary, count, labelled, prefixed?) do
    case dictionary(binary, count, prefixed?) do
      {:ok, dictionary, rest} -> dictionary_lookups(rest, List.to_tuple(dictionary), labelled)
      :error -> :error
    end
  end

  # Each labelled tile's index into the dictionary.
  defp dictionary_lookups(binary, dictionary, labelled) do
    case read_n(binary, labelled, &bounded_varuint(&1, 0, tuple_size(dictionary) - 1)) do
      {:ok, indexes, rest} -> {:ok, Enum.map(indexes, &elem(dictionary, &1)), rest}
      :error -> :error
    end
  end

  defp dictionary(binary, count, false),
    do: read_n(binary, count, &string(&1, 1, @max_label_bytes))

  # Each entry reuses the first `prefix` bytes of the one before it.
  defp dictionary(binary, count, true) do
    read_each(1..count, binary, fn _index, rest, previous ->
      prefixed_entry(rest, List.first(previous, ""))
    end)
  end

  defp prefixed_entry(binary, previous) do
    case varuint_pair(binary) do
      {:ok, {prefix, suffix_length}, rest}
      when prefix <= byte_size(previous) and (prefix + suffix_length) in 1..@max_label_bytes ->
        take(rest, suffix_length, &(binary_part(previous, 0, prefix) <> &1))

      {:ok, _out_of_range, _rest} ->
        :error

      :error ->
        :error
    end
  end

  defp attach_labels(tiles, labels) do
    {tiles, []} =
      Enum.map_reduce(tiles, labels, fn
        %{label: true} = tile, [label | rest] -> {%{tile | label: label}, rest}
        tile, rest -> {%{tile | label: nil}, rest}
      end)

    tiles
  end

  # `count` values from `reader`, one after the other.
  defp read_n(binary, count, reader),
    do: read_each(List.duplicate(nil, count), binary, fn _slot, rest, _acc -> reader.(rest) end)

  # Runs `step` over `items`, threading the unread bytes; values come back in order.
  defp read_each(items, binary, step) do
    result =
      Enum.reduce_while(items, {:ok, [], binary}, fn item, {:ok, acc, rest} ->
        case step.(item, rest, acc) do
          {:ok, value, rest} -> {:cont, {:ok, [value | acc], rest}}
          :error -> {:halt, :error}
        end
      end)

    case result do
      {:ok, values, rest} -> {:ok, Enum.reverse(values), rest}
      :error -> :error
    end
  end

  # A varuint length (min..max bytes) followed by that many bytes.
  defp string(binary, min, max) do
    case bounded_varuint(binary, min, max) do
      {:ok, length, rest} -> take(rest, length, & &1)
      :error -> :error
    end
  end

  defp take(binary, length, wrap) do
    case binary do
      <<value::binary-size(^length), rest::binary>> -> {:ok, wrap.(value), rest}
      _too_short -> :error
    end
  end

  defp bounded_varuint(binary, min, max) do
    case varuint(binary) do
      {:ok, value, rest} when value >= min and value <= max -> {:ok, value, rest}
      {:ok, _out_of_range, _rest} -> :error
      :error -> :error
    end
  end

  defp varuint_pair(binary) do
    case varuint(binary) do
      {:ok, first, rest} -> second_varuint(rest, first)
      :error -> :error
    end
  end

  defp second_varuint(binary, first) do
    case varuint(binary) do
      {:ok, second, rest} -> {:ok, {first, second}, rest}
      :error -> :error
    end
  end

  # LEB128, at most 9 bytes.
  defp varuint(binary, shift \\ 0, value \\ 0)
  defp varuint(_binary, 63, _value), do: :error

  defp varuint(<<0::1, byte::7, rest::binary>>, shift, value),
    do: {:ok, value ||| byte <<< shift, rest}

  defp varuint(<<1::1, byte::7, rest::binary>>, shift, value),
    do: varuint(rest, shift + 7, value ||| byte <<< shift)

  defp varuint(_binary, _shift, _value), do: :error

  defp zigzag(value) when rem(value, 2) == 0, do: div(value, 2)
  defp zigzag(value), do: -div(value + 1, 2)
end
