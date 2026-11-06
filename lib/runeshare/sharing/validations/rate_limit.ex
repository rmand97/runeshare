defmodule Runeshare.Sharing.Validations.RateLimit do
  @moduledoc """
  Rejects a create when the actor already made `max` records of this resource in the
  last `per_seconds`. Counted in the database, so it holds across restarts and nodes.

      validate {RateLimit, max: 10, per_seconds: 3600, field: :author_id}
  """

  use Ash.Resource.Validation

  require Ash.Query
  require Logger

  @impl Ash.Resource.Validation
  def init(opts) do
    if is_integer(opts[:max]) and is_integer(opts[:per_seconds]) and is_atom(opts[:field]),
      do: {:ok, opts},
      else: {:error, "expected integer :max and :per_seconds and an atom :field"}
  end

  @impl Ash.Resource.Validation
  def validate(changeset, opts, %{actor: %{id: actor_id} = actor}) do
    cutoff = DateTime.add(DateTime.utc_now(), -opts[:per_seconds], :second)
    field = opts[:field]

    count =
      changeset.resource
      |> Ash.Query.filter(^ref(field) == ^actor_id and inserted_at > ^cutoff)
      |> Ash.count!(actor: actor)

    if count < opts[:max] do
      :ok
    else
      Logger.warning(
        "rate limit hit: #{inspect(changeset.resource)} #{opts[:max]} per #{opts[:per_seconds]}s actor=user:#{actor_id}",
        actor_id: actor_id
      )

      {:error, message: "you're doing that too often — please wait a while and try again"}
    end
  end

  # No actor: the action's policies reject the request.
  def validate(_changeset, _opts, _context), do: :ok
end
