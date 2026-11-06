defmodule Runeshare.Repo.SlowQueryLogTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Runeshare.Repo.SlowQueryLog

  @query ~s|SELECT p0."id" FROM "presets" AS p0 WHERE (p0."title" = $1)|

  test "a slow query logs its SQL and table, not its parameters" do
    log =
      capture_log(fn ->
        SlowQueryLog.handle_event(
          [:runeshare, :repo, :query],
          %{total_time: System.convert_time_unit(6_000, :millisecond, :native)},
          %{source: "presets", query: @query, params: ["secret title"]},
          nil
        )
      end)

    assert log =~ "[warning] slow query 6000ms source=presets SELECT"
    refute log =~ "secret title"
  end

  test "a fast query logs nothing" do
    log =
      capture_log(fn ->
        SlowQueryLog.handle_event(
          [:runeshare, :repo, :query],
          %{total_time: System.convert_time_unit(3, :millisecond, :native)},
          %{source: "fast_presets", query: @query, params: []},
          nil
        )
      end)

    refute log =~ "source=fast_presets"
  end
end
