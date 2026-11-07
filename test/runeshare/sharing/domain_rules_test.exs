defmodule Runeshare.Sharing.DomainRulesTest do
  @moduledoc false
  # Rules the web layer used to decide for itself and now asks the domain about.
  use Runeshare.DataCase, async: true

  alias Runeshare.Accounts
  alias Runeshare.Sharing

  describe "preset permissions (can_*? from the policies)" do
    test "the author may edit and delete but not hide; others may do none of it" do
      author = register_user!()
      preset = share_preset!(author)
      other = register_user!()

      assert Sharing.can_edit_preset?(author, preset)
      assert Sharing.can_delete_preset?(author, preset)
      refute Sharing.can_hide_preset?(author, preset)

      for actor <- [other, nil] do
        refute Sharing.can_edit_preset?(actor, preset)
        refute Sharing.can_delete_preset?(actor, preset)
        refute Sharing.can_hide_preset?(actor, preset)
      end

      assert Sharing.can_hide_preset?(register_admin!(), preset)
    end
  end

  describe "reporting" do
    test "anyone signed in may report someone else's preset, never their own" do
      author = register_user!()
      preset = share_preset!(author)
      reporter = register_user!()

      assert Sharing.can_report_preset?(reporter, preset.id, :spam)
      refute Sharing.can_report_preset?(author, preset.id, :spam)
      refute Sharing.can_report_preset?(nil, preset.id, :spam)

      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.report_preset(preset.id, :spam, actor: author)
    end

    test "hiding a reported preset resolves the report in the same step; only admins may" do
      author = register_user!()
      preset = share_preset!(author)
      Sharing.report_preset!(preset.id, :offensive, actor: register_user!())
      admin = register_admin!()
      [report] = Sharing.list_open_reports!(actor: admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.hide_reported_preset(report, actor: author)

      assert %{status: :resolved, preset: %{hidden: true}} =
               Sharing.hide_reported_preset!(report, actor: admin)

      assert [] = Sharing.list_open_reports!(actor: admin)
      assert {:ok, %{hidden: true}} = Sharing.get_preset(preset.id, actor: author)
    end
  end

  describe "comment delete button" do
    test "removable by its author, the preset's author and admins only" do
      preset_author = register_user!()
      preset = share_preset!(preset_author)
      commenter = register_user!()
      comment = Sharing.post_comment!(preset.id, "hi", actor: commenter)

      removable? = fn actor ->
        Sharing.get_comment!(comment.id, actor: actor).removable_by_actor
      end

      assert removable?.(commenter)
      assert removable?.(preset_author)
      assert removable?.(register_admin!())
      refute removable?.(register_user!())
      refute removable?.(nil)
    end
  end

  describe "likes" do
    test "set_like likes and unlikes, each idempotent; signed-out visitors may not" do
      preset = share_preset!(register_user!())
      fan = register_user!()
      likes = fn -> Sharing.get_preset!(preset.id, actor: fan).like_count end

      assert Sharing.set_like!(preset.id, true, actor: fan) == :liked
      assert Sharing.set_like!(preset.id, true, actor: fan) == :liked
      assert likes.() == 1

      assert Sharing.set_like!(preset.id, false, actor: fan) == :unliked
      assert Sharing.set_like!(preset.id, false, actor: fan) == :unliked
      assert likes.() == 0

      assert {:error, %Ash.Error.Forbidden{}} = Sharing.set_like(preset.id, true)
    end
  end

  describe "front-page stats" do
    test "count visible presets per kind, in kind order, and the newest share" do
      author = register_user!()
      share_preset!(author, %{kind: :tile_marker})
      share_preset!(author)
      hidden = share_preset!(author)
      Sharing.hide_preset!(hidden, actor: register_admin!())

      stats = Sharing.preset_stats!()

      assert stats.counts == [watchdog_alarm: 1, tile_marker: 1]
      assert %DateTime{} = stats.last_shared
    end
  end

  describe "moderators" do
    test "Accounts.admin?/1" do
      assert Accounts.admin?(register_admin!())
      refute Accounts.admin?(register_user!())
      refute Accounts.admin?(nil)
    end
  end
end
