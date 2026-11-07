defmodule Runeshare.Sharing.Like.Set do
  @moduledoc """
  Makes the actor's like on a preset what they asked for: `liked: true` likes it
  (an upsert, so liking twice is fine), `liked: false` unlikes it (a like already
  gone, say removed in another tab, counts as done). Returns `:liked` or
  `:unliked`. Taking the wanted state rather than toggling keeps a stale page
  doing what its button said.
  """

  use Ash.Resource.Actions.Implementation

  alias Runeshare.Sharing

  @impl Ash.Resource.Actions.Implementation
  def run(%{arguments: %{preset_id: preset_id, liked: true}}, _opts, context) do
    case Sharing.like_preset(preset_id, Ash.Context.to_opts(context)) do
      {:ok, _like} -> {:ok, :liked}
      {:error, error} -> {:error, error}
    end
  end

  def run(%{arguments: %{preset_id: preset_id, liked: false}}, _opts, context) do
    case Sharing.unlike_preset(preset_id, context.actor.id, Ash.Context.to_opts(context)) do
      :ok -> {:ok, :unliked}
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} -> {:ok, :unliked}
      {:error, error} -> {:error, error}
    end
  end
end
