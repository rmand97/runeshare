defmodule Runeshare.Sharing.VersionsTest do
  use Runeshare.DataCase, async: true

  alias Runeshare.Sharing

  describe "versions" do
    test "sharing creates v1; each edit adds the next version and keeps the old ones" do
      author = register_user!()
      preset = share_preset!(author, %{title: "Original"})
      assert preset.version == 1

      v2 = Sharing.edit_preset!(preset, %{title: "Second"}, actor: author)
      v3 = Sharing.edit_preset!(v2, %{description: "Now with notes"}, actor: author)

      assert v3.version == 3

      assert [%{number: 3}, %{number: 2, title: "Second"}, %{number: 1, title: "Original"}] =
               Sharing.list_preset_versions!(preset.id)

      assert %{title: "Original"} = Sharing.get_preset_version!(preset.id, 1)
      assert %{title: "Second", description: "Now with notes"} = Sharing.get_preset!(preset.id)
    end

    test "an edit that only changes tags, or nothing, keeps the current version" do
      author = register_user!()
      preset = share_preset!(author)

      retagged = Sharing.edit_preset!(preset, %{tags: ["vorago"]}, actor: author)
      unchanged = Sharing.edit_preset!(retagged, %{title: preset.title}, actor: author)

      assert %{version: 1, tags: ["vorago"]} = unchanged
      assert [%{number: 1}] = Sharing.list_preset_versions!(preset.id)
    end

    test "a rejected edit creates no version" do
      author = register_user!()
      preset = share_preset!(author)

      assert {:error, _invalid} = Sharing.edit_preset(preset, %{content: "junk"}, actor: author)
      assert [%{number: 1}] = Sharing.list_preset_versions!(preset.id)
    end

    test "deleting a preset deletes its versions" do
      author = register_user!()
      preset = share_preset!(author)
      Sharing.delete_preset!(preset, actor: author)

      assert [] = Sharing.list_preset_versions!(preset.id)
    end
  end
end
