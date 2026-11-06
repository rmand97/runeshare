defmodule Runeshare.Repo.SlowQueryLog do
  @moduledoc """
  Logs a warning for every database query slower than `:slow_query_ms`
  (`config :runeshare, :slow_query_ms`, default 200). Ecto's own query log is
  `:debug`, so production otherwise never sees SQL at all.

  Logs the SQL with its `$1` placeholders and the table, never the parameters.
  """

  require Logger

  @event [:runeshare, :repo, :query]
  @default_threshold_ms 200

  @doc "Attaches the telemetry handler. Called once from `Runeshare.Application`."
  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    :telemetry.attach("#{__MODULE__}", @event, &__MODULE__.handle_event/4, nil)
  end

  @doc false
  @spec handle_event(list(atom()), map(), map(), term()) :: :ok
  def handle_event(_event, measurements, metadata, _config) do
    total_ms =
      measurements
      |> Map.get(:total_time, 0)
      |> System.convert_time_unit(:native, :millisecond)

    if total_ms >= threshold_ms() do
      Logger.warning(
        fn -> "slow query #{total_ms}ms source=#{metadata[:source]} #{metadata[:query]}" end,
        slow_query_ms: total_ms,
        source: metadata[:source]
      )
    end

    :ok
  end

  defp threshold_ms, do: Application.get_env(:runeshare, :slow_query_ms, @default_threshold_ms)
end
