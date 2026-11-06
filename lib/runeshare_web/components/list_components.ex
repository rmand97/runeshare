defmodule RuneshareWeb.ListComponents do
  @moduledoc """
  Pieces for paged lists inside a page (see `RuneshareWeb.Paging`).
  """

  use Phoenix.Component

  @doc """
  "Show more" button under (or, with `position="top"`, above) a paged list.
  Hidden once everything is loaded.
  """
  attr :id, :string, required: true
  attr :event, :string, required: true, doc: "the phx-click event that loads the next page"
  attr :paging, :map, required: true, doc: "`@paging.<list>` from RuneshareWeb.Paging"
  attr :label, :string, default: "Show more"
  attr :position, :string, default: "bottom", values: ~w(top bottom)

  def load_more(assigns) do
    assigns = assign(assigns, :remaining, RuneshareWeb.Paging.remaining(assigns.paging))

    ~H"""
    <div
      :if={@remaining > 0}
      class={[
        "border-base-content/10 p-2",
        if(@position == "top", do: "border-b", else: "border-t")
      ]}
    >
      <button
        id={@id}
        type="button"
        phx-click={@event}
        phx-disable-with="Loading…"
        class="btn btn-block btn-ghost btn-sm"
      >
        {@label} <span class="font-mono text-base-content/60">({@remaining} more)</span>
      </button>
    </div>
    """
  end
end
