defmodule Runeshare.SlotTest do
  use ExUnit.Case, async: false

  alias Runeshare.Slot

  describe "slot 0 keeps the historical single-developer setup" do
    test "ports and database names are unchanged" do
      assert Slot.suffix(0) == ""
      assert Slot.dev_port(0) == 4000
      assert Slot.test_port(0) == 4040
      assert Slot.database(0, "runeshare_dev") == "runeshare_dev"
      assert Slot.database(0, "runeshare_test") == "runeshare_test"
    end

    test "current/0 defaults to 0 when RUNESHARE_SLOT is unset" do
      assert Slot.current() == 0
    end
  end

  describe "a worktree slot isolates every port and database" do
    test "slot 3 gets its own block" do
      assert Slot.dev_port(3) == 4003
      assert Slot.test_port(3) == 4043
      assert Slot.database(3, "runeshare_dev") == "runeshare_dev_3"
      assert Slot.database(3, "runeshare_test") == "runeshare_test_3"
    end

    test "no two slots in 0..9 share a port" do
      ports =
        Enum.flat_map(0..9, fn slot ->
          [Slot.dev_port(slot), Slot.test_port(slot)]
        end)

      assert Enum.count(Enum.uniq(ports)) == Enum.count(ports)
    end
  end

  describe "current/0" do
    test "reads RUNESHARE_SLOT" do
      System.put_env("RUNESHARE_SLOT", "7")
      on_exit(fn -> System.delete_env("RUNESHARE_SLOT") end)

      assert Slot.current() == 7
    end

    test "rejects a slot outside 0..9" do
      System.put_env("RUNESHARE_SLOT", "42")
      on_exit(fn -> System.delete_env("RUNESHARE_SLOT") end)

      assert_raise ArgumentError, ~r/RUNESHARE_SLOT must be 0\.\.9/, &Slot.current/0
    end
  end

  describe "free_port/2" do
    test "skips a port that is already bound" do
      {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, taken} = :inet.port(socket)

      assert Slot.free_port(taken, 10) != taken

      :gen_tcp.close(socket)
    end

    test "returns nil when the whole window is unavailable" do
      # Port 0 means "any port" to the OS, so a one-wide window at a privileged
      # port is the reliable way to get an exhausted window.
      assert Slot.free_port(1, 1) == nil
    end
  end
end
