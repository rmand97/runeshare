defmodule Mix.Tasks.Runeshare.Slot do
  @shortdoc "Print the ports, databases and URLs this checkout owns"

  @moduledoc """
  Print the ports, databases and URLs this checkout owns.

      $ mix runeshare.slot

  Everything derives from the `RUNESHARE_SLOT` environment variable (default 0),
  which `bin/agent-worktree` writes into each worktree's `.env`. Run this before
  starting a server or assuming a URL — with several agent worktrees active,
  port 4000 probably belongs to someone else.

  The dev values are read back from the configuration that is actually in
  effect, so this cannot drift from `config/runtime.exs`. The test values are
  computed, since test configuration is not loaded in this environment.

  See the `parallel-agents` skill for the full workflow.
  """

  use Mix.Task

  alias Runeshare.Slot

  # runtime.exs is what applies the slot, and only app.config loads it.
  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    slot = Slot.current()
    endpoint = Application.get_env(:runeshare, RuneshareWeb.Endpoint, [])
    dev_port = get_in(endpoint, [:http, :port]) || Slot.dev_port(slot)
    debugger_port = Application.get_env(:live_debugger, :port, Slot.debugger_port(slot))
    dev_database = Application.get_env(:runeshare, Runeshare.Repo, [])[:database]

    Mix.shell().info("""
    slot            #{slot}#{if slot == 0, do: "  (default — RUNESHARE_SLOT unset)", else: ""}
    dev server      http://localhost:#{dev_port}
    live debugger   http://localhost:#{debugger_port}
    tidewave mcp    http://localhost:#{dev_port}/tidewave/mcp
    ash_ai mcp      http://localhost:#{dev_port}/ash_ai/mcp
    test endpoint   http://localhost:#{Slot.test_port(slot)}
    dev database    #{dev_database}
    test database   #{Slot.database(slot, "runeshare_test")}
    """)
  end
end
