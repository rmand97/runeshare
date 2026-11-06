defmodule Runeshare.ActionLog do
  @moduledoc """
  One log line per Ash action: who ran it, which action, how long it took, and how
  it ended. Wired in as the global `Ash.Tracer` (`config :ash, :tracer`), so every
  code-interface call is covered without a `Logger` call at the call site.

      [info] Sharing.Preset.share ok in 14ms actor=user:7c0e… id=1b9f…
      [info] Sharing.Comment.post invalid in 3ms actor=user:7c0e… errors=[InvalidAttribute(body): …]
      [warning] Sharing.Preset.edit forbidden in 2ms actor=user:51aa… errors=[Forbidden.Policy]

  Levels keep production quiet: successful top-level writes at `:info`, reads and
  nested actions (a version snapshot inside `share`) at `:debug`, relationship loads
  inside another action not at all. Invalid input (including rate limits) is `:info`,
  forbidden is `:warning`, framework and unknown errors are `:error`.

  The same fields go into Logger metadata (`ash_action`, `outcome`, `duration_ms`,
  `actor_id`, `record_id`, `error_class`) for the JSON formatter in production.

  Never logged: action inputs (arguments or attributes, sensitive or not), the
  actor beyond its id, and policy breakdowns. Error messages are only included for
  framework/unknown errors, with email addresses masked.

  `Runeshare.ActionLog.Notifier` adds the id of the written record; Ash's tracer
  callbacks do not see results.
  """

  use Ash.Tracer

  alias Ash.Resource.Info

  require Logger

  @state_key __MODULE__
  @span_types [:action, :bulk_create, :bulk_update, :bulk_destroy]
  # Internal bookkeeping (session tokens, file blobs): successes stay at debug.
  @quiet_resources [
    Runeshare.Accounts.Token,
    Runeshare.Sharing.StorageBlob,
    Runeshare.Sharing.StorageAttachment
  ]
  @max_message_length 500

  @impl Ash.Tracer
  def trace_type?(type), do: type in @span_types

  @impl Ash.Tracer
  def start_span(type, _name) do
    span = %{
      type: type,
      depth: depth(),
      started_at: System.monotonic_time(),
      metadata: %{},
      error: nil,
      record_id: nil
    }

    put_stack([span | stack()])
  end

  @impl Ash.Tracer
  def stop_span do
    case stack() do
      [span | rest] ->
        put_stack(rest)
        log(span)

      [] ->
        :ok
    end
  end

  @impl Ash.Tracer
  # The first metadata after `start_span/2` describes the action. Ash's notifier
  # and calculation spans later report theirs under the `:action` type too, while
  # the action's span is still the innermost open one, so those are ignored.
  def set_metadata(_type, %{action: action} = metadata) when is_atom(action) do
    update_top(fn
      %{metadata: empty} = span when map_size(empty) == 0 -> %{span | metadata: metadata}
      span -> span
    end)
  end

  def set_metadata(_type, _metadata), do: :ok

  @impl Ash.Tracer
  def set_handled_error(error, _opts), do: update_top(&%{&1 | error: error})

  @impl Ash.Tracer
  def set_error(error, _opts), do: update_top(&%{&1 | error: error})

  @impl Ash.Tracer
  def set_error(error), do: set_error(error, [])

  # Ash hands the context to processes it spawns (async loads), so their actions
  # count as nested instead of logging as top-level.
  @impl Ash.Tracer
  def get_span_context, do: depth()

  @impl Ash.Tracer
  def set_span_context(depth) when is_integer(depth),
    do: put_state(%{state() | base_depth: depth})

  def set_span_context(_context), do: :ok

  @doc """
  Adds the id of the record an action wrote to the action's log line. Called by
  `Runeshare.ActionLog.Notifier`; ignored unless the innermost open span is that
  resource's action.

  With no span open at all, logs the write on its own, untimed: Ash 3.37 starts
  the outer span of a query-based bulk update/destroy (e.g. a destroy code
  interface with `get_by`) before it adds the configured tracer, so those
  actions never reach `start_span/2`.
  """
  @spec record_written(Ash.Notifier.Notification.t()) :: :ok
  def record_written(%Ash.Notifier.Notification{data: %{id: id}} = notification) do
    resource = notification.resource
    action = notification.action.name

    case stack() do
      [] ->
        emit(level("ok", false, true, resource), "ok", resource, action, %{
          started_at: nil,
          metadata: %{actor: notification.actor},
          record_id: id,
          error: nil
        })

      _open ->
        update_top(fn
          %{metadata: %{resource: ^resource, action: ^action}} = span -> %{span | record_id: id}
          span -> span
        end)
    end
  end

  def record_written(_notification), do: :ok

  # Ash.Tracer callbacks carry no state, and spans open and close in the calling
  # process, so the open spans live in its process dictionary.
  # credo:disable-for-next-definition Bylaw.Credo.Check.Elixir.NoLowLevelProcessPrimitives
  defp state, do: Process.get(@state_key, %{stack: [], base_depth: 0})

  # credo:disable-for-next-definition Bylaw.Credo.Check.Elixir.NoLowLevelProcessPrimitives
  defp put_state(state) do
    Process.put(@state_key, state)
    :ok
  end

  defp stack, do: state().stack
  defp put_stack(stack), do: put_state(%{state() | stack: stack})
  defp depth, do: Enum.count(stack()) + state().base_depth

  defp update_top(fun) do
    case stack() do
      [span | rest] -> put_stack([fun.(span) | rest])
      [] -> :ok
    end
  end

  defp log(%{metadata: %{resource: resource, action: action}} = span) when is_atom(action) do
    outcome = outcome(span.error)
    nested? = span.depth > 0
    write? = write?(resource, action)

    case level(outcome, nested?, write?, resource) do
      nil -> :ok
      level -> emit(level, outcome, resource, action, span)
    end
  end

  defp log(_span), do: :ok

  defp emit(level, outcome, resource, action, span) do
    name = action_name(resource, action)
    duration_ms = duration_ms(span.started_at)
    actor = actor(span.metadata)

    parts = [
      if(duration_ms, do: "#{name} #{outcome} in #{duration_ms}ms", else: "#{name} #{outcome}"),
      "actor=#{actor}",
      span.record_id && "id=#{span.record_id}",
      span.error && "errors=#{describe(span.error)}"
    ]

    metadata =
      Enum.reject(
        [
          ash_action: name,
          outcome: outcome,
          duration_ms: duration_ms,
          actor_id: actor_id(span.metadata),
          record_id: span.record_id,
          error_class: span.error && error_class(span.error)
        ],
        fn {_key, value} -> is_nil(value) end
      )

    Logger.log(level, fn -> parts |> Enum.reject(&is_nil/1) |> Enum.join(" ") end, metadata)
  end

  defp outcome(nil), do: "ok"
  defp outcome(%Ash.Error.Invalid{}), do: "invalid"
  defp outcome(%Ash.Error.Forbidden{}), do: "forbidden"
  defp outcome(_error), do: "error"

  # Relationship loads and other reads inside an action: not worth a line.
  defp level("ok", true, false, _resource), do: nil
  defp level("ok", true, true, _resource), do: :debug
  defp level("ok", false, false, _resource), do: :debug
  defp level("ok", false, true, resource) when resource in @quiet_resources, do: :debug
  defp level("ok", false, true, _resource), do: :info
  defp level("invalid", _nested?, _write?, _resource), do: :info
  defp level("forbidden", _nested?, _write?, _resource), do: :warning
  defp level("error", _nested?, _write?, _resource), do: :error

  defp write?(resource, action) do
    case Info.action(resource, action) do
      %{type: :read} -> false
      _other -> true
    end
  end

  defp action_name(resource, action) do
    resource
    |> inspect()
    |> String.replace_prefix("Runeshare.", "")
    |> Kernel.<>(".#{action}")
  end

  defp duration_ms(nil), do: nil

  defp duration_ms(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)
  end

  defp actor(%{actor: %{id: id}}), do: "user:#{id}"
  defp actor(%{authorize?: false}), do: "system"
  defp actor(_metadata), do: "anon"

  defp actor_id(%{actor: %{id: id}}), do: id
  defp actor_id(_metadata), do: nil

  defp error_class(%{class: class}), do: class
  defp error_class(error), do: inspect(error.__struct__)

  defp describe(%{class: class, errors: errors}) when class in [:invalid, :forbidden] do
    errors |> Enum.map_join(", ", &describe_inner/1) |> bracket()
  end

  defp describe(error), do: error |> Exception.message() |> mask_emails() |> bracket()

  defp bracket(text), do: "[" <> String.slice(text, 0, @max_message_length) <> "]"

  # Field name and the validation's own message template only — never the
  # rejected value, which `Exception.message/1` would append.
  defp describe_inner(error) do
    kind = error.__struct__ |> inspect() |> String.replace_prefix("Ash.Error.", "")
    field = Map.get(error, :field) || Map.get(error, :fields)
    fields = if field, do: "(#{Enum.join(List.wrap(field), ",")})", else: ""

    case Map.get(error, :message) do
      message when is_binary(message) -> "#{kind}#{fields}: #{render(message, error)}"
      _none -> kind <> fields
    end
  end

  # Fills in `%{min}`-style placeholders from numbers and atoms only: strings in
  # `vars` can be user input.
  defp render(message, error) do
    error
    |> Map.get(:vars, [])
    |> Enum.reduce(message, fn
      {key, value}, acc when is_number(value) or (is_atom(value) and not is_nil(value)) ->
        String.replace(acc, "%{#{key}}", to_string(value))

      _var, acc ->
        acc
    end)
    |> mask_emails()
  end

  defp mask_emails(text), do: Regex.replace(~r/[\w.+-]+@[\w-]+(\.[\w-]+)+/, text, "[email]")
end
