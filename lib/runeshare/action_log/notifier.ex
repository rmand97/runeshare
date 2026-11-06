defmodule Runeshare.ActionLog.Notifier do
  @moduledoc """
  Hands the id of a written record to `Runeshare.ActionLog`, so the action's log
  line says which preset was hidden or which comment was removed. Add it to a
  resource with `simple_notifiers: [Runeshare.ActionLog.Notifier]`.
  """

  use Ash.Notifier

  @impl Ash.Notifier
  def notify(notification), do: Runeshare.ActionLog.record_written(notification)
end
