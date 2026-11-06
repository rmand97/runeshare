defmodule Runeshare.Sharing.VersionMergeTest do
  # Not async: turns on the merge window, which is global config.
  use Runeshare.DataCase, async: false

  alias Runeshare.Sharing

  setup do
    previous = Application.get_env(:runeshare, :version_merge_window_seconds)
    Application.put_env(:runeshare, :version_merge_window_seconds, 30 * 60)
    on_exit(fn -> Application.put_env(:runeshare, :version_merge_window_seconds, previous) end)
  end

  test "a quick re-edit updates the newest version instead of adding one" do
    author = register_user!()
    preset = share_preset!(author, %{title: "Original"})

    edited =
      Sharing.edit_preset!(preset, %{title: "Typo fixed", change_note: "Fixed"}, actor: author)

    edited = Sharing.edit_preset!(edited, %{description: "Now with notes"}, actor: author)

    assert edited.version == 1

    assert [%{number: 1, title: "Typo fixed", description: "Now with notes", note: "Fixed"}] =
             Sharing.list_preset_versions!(preset.id)
  end
end
