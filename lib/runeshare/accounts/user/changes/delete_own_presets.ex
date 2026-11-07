defmodule Runeshare.Accounts.User.Changes.DeleteOwnPresets do
  @moduledoc """
  Before a user is deleted, deletes their presets through Ash, so each preset's
  cover image file is purged from storage and open listings hear about it. The
  database would cascade the rows on its own, but not the files.

  Comments, likes and reports they made are removed by the database (they hold
  no files and no one is subscribed to them by user).

  Runs before the user's own transaction: each preset is deleted (and its file
  purged) in its own transaction, so no file is purged for a delete that later
  rolls back. If deleting the user then fails, their presets are already gone
  and trying again finishes the job.
  """

  use Ash.Resource.Change

  alias Runeshare.Sharing

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      user = changeset.data

      [actor: user, page: false]
      |> Sharing.list_my_presets!()
      |> Enum.each(&Sharing.delete_preset!(&1, actor: user))

      changeset
    end)
  end
end
