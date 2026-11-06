defmodule Runeshare.Slot do
  @moduledoc """
  Development slot allocation, so several agents can run the app side by side.

  A slot is an integer 0..9 read from the `RUNESHARE_SLOT` environment variable.
  Every port and database name derives from it, so nothing has to be looked up
  or coordinated between checkouts. Slot 0 is the historical single-developer
  setup: port 4000, database `runeshare_dev`.

  `config/runtime.exs` inlines the same arithmetic (config is evaluated before
  this module is compiled, so it cannot call in here). Keep the two in step —
  `test/runeshare/slot_test.exs` pins the numbers.
  """

  @max_slot 9
  @dev_base 4000
  @debugger_base 4020
  @test_base 4040

  @doc "Slot for the current checkout, from `RUNESHARE_SLOT` (default 0)."
  @spec current() :: non_neg_integer()
  def current do
    slot = String.to_integer(System.get_env("RUNESHARE_SLOT", "0"))

    if slot in 0..@max_slot do
      slot
    else
      raise ArgumentError, "RUNESHARE_SLOT must be 0..#{@max_slot}, got #{slot}"
    end
  end

  @doc "Suffix appended to database names. Empty for slot 0."
  @spec suffix(non_neg_integer()) :: String.t()
  def suffix(0), do: ""
  def suffix(slot), do: "_#{slot}"

  @doc "Port the dev server binds to."
  @spec dev_port(non_neg_integer()) :: pos_integer()
  def dev_port(slot), do: @dev_base + slot

  @doc "Port LiveDebugger binds to."
  @spec debugger_port(non_neg_integer()) :: pos_integer()
  def debugger_port(slot), do: @debugger_base + slot

  @doc "Port the test endpoint binds to."
  @spec test_port(non_neg_integer()) :: pos_integer()
  def test_port(slot), do: @test_base + slot

  @doc "Database name for `base` — `runeshare_dev` or `runeshare_test` — in this slot."
  @spec database(non_neg_integer(), String.t()) :: String.t()
  def database(slot, base), do: base <> suffix(slot)

  @doc """
  First free TCP port at or after `from`, used when no slot or `PORT` is set.

  Returns `nil` when the whole window is taken.
  """
  @spec free_port(pos_integer(), pos_integer()) :: pos_integer() | nil
  def free_port(from \\ @dev_base, window \\ 100) do
    Enum.find(from..(from + window - 1), fn port ->
      case :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true]) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true

        {:error, _reason} ->
          false
      end
    end)
  end
end
