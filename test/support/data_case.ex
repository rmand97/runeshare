defmodule Runeshare.DataCase do
  @moduledoc """
  Test case for domain tests that touch the database. Each test runs in an
  Ecto SQL sandbox, rolled back afterwards.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Runeshare.DataCase
      import Runeshare.Test.Builders
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  @doc "Starts a sandbox owner for the test and returns its pid."
  @spec setup_sandbox(map()) :: pid()
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Runeshare.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    pid
  end
end
