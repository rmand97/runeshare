defmodule Runeshare.Sharing.Preset.Actions.Stats do
  @moduledoc """
  Public totals for the front page: how many visible presets each kind has
  (in `Preset.kinds/0` order) and when the newest visible one was shared.
  Counts what everyone can see, whoever asks: read as a signed-out visitor, so
  hidden presets never count.
  """

  use Ash.Resource.Actions.Implementation

  alias Runeshare.Sharing.Preset

  require Ash.Query

  @impl Ash.Resource.Actions.Implementation
  def run(_input, _opts, _context) do
    visible = Ash.Query.filter(Preset, hidden == false)

    counts =
      Enum.map(Preset.kinds(), fn kind ->
        {kind, visible |> Ash.Query.filter(kind == ^kind) |> Ash.count!(actor: nil)}
      end)

    {:ok, %{counts: counts, last_shared: Ash.max!(visible, :inserted_at, actor: nil)}}
  end
end
