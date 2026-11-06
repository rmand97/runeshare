defmodule Runeshare.Sharing.EngagementTest do
  use Runeshare.DataCase, async: true

  alias Runeshare.Sharing

  describe "likes" do
    test "liking is idempotent, counted, and reflected in liked_by_me" do
      preset = share_preset!(register_user!())
      fan = register_user!()

      Sharing.like_preset!(preset.id, actor: fan)
      Sharing.like_preset!(preset.id, actor: fan)

      assert %{like_count: 1, liked_by_me: true} = Sharing.get_preset!(preset.id, actor: fan)
      assert %{liked_by_me: false} = Sharing.get_preset!(preset.id, actor: register_user!())

      Sharing.unlike_preset!(preset.id, fan.id, actor: fan)
      assert %{like_count: 0, liked_by_me: false} = Sharing.get_preset!(preset.id, actor: fan)
    end

    test "anonymous visitors cannot like, and nobody can remove someone else's like" do
      preset = share_preset!(register_user!())
      fan = register_user!()
      Sharing.like_preset!(preset.id, actor: fan)

      assert {:error, %Ash.Error.Forbidden{}} = Sharing.like_preset(preset.id)

      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.unlike_preset(preset.id, fan.id, actor: register_user!())
    end

    test "the listing can be sorted by likes" do
      author = register_user!()
      share_preset!(author, %{title: "Quiet"})
      popular = share_preset!(author, %{title: "Popular"})
      Sharing.like_preset!(popular.id, actor: register_user!())

      assert [%{title: "Popular"}, %{title: "Quiet"}] =
               Sharing.list_presets!(:watchdog_alarm, %{sort: :most_liked})
    end
  end

  describe "comments" do
    test "signed-in users comment; comments list oldest first with authors" do
      preset = share_preset!(register_user!())
      alice = register_user!(name: "Alice")
      bob = register_user!(name: "Bob")

      Sharing.post_comment!(preset.id, "First!", actor: alice)
      Sharing.post_comment!(preset.id, "Works great", actor: bob)

      assert [%{body: "First!", author: %{name: "Alice"}}, %{body: "Works great"}] =
               Sharing.list_comments!(preset.id)

      assert %{comment_count: 2} = Sharing.get_preset!(preset.id)
      assert {:error, %Ash.Error.Forbidden{}} = Sharing.post_comment(preset.id, "anon")
    end

    test "a comment can be removed by its author or the preset's author, nobody else" do
      owner = register_user!()
      preset = share_preset!(owner)
      commenter = register_user!()
      first = Sharing.post_comment!(preset.id, "one", actor: commenter)
      second = Sharing.post_comment!(preset.id, "two", actor: commenter)

      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.remove_comment(first, actor: register_user!())

      assert :ok = Sharing.remove_comment!(first, actor: commenter)
      assert :ok = Sharing.remove_comment!(second, actor: owner)
      assert [] = Sharing.list_comments!(preset.id)
    end
  end
end
