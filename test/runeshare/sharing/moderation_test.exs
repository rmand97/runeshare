defmodule Runeshare.Sharing.ModerationTest do
  use Runeshare.DataCase, async: true

  alias Runeshare.Sharing

  describe "roles" do
    test "ADMIN_EMAILS addresses sign in as admins, everyone else as users" do
      assert register_admin!().role == :admin
      assert register_user!().role == :user
    end
  end

  describe "reports" do
    test "users report a preset once; admins see and resolve open reports" do
      preset = share_preset!(register_user!())
      reporter = register_user!()
      admin = register_admin!()

      Sharing.report_preset!(preset.id, :broken, %{note: "Doesn't import"}, actor: reporter)
      Sharing.report_preset!(preset.id, :spam, actor: reporter)

      assert [%{reason: :spam} = report] = Sharing.list_open_reports!(actor: admin)
      # Read policies filter: non-admins simply see no reports.
      assert [] = Sharing.list_open_reports!(actor: reporter)
      assert {:error, %Ash.Error.Forbidden{}} = Sharing.report_preset(preset.id, :spam)

      Sharing.resolve_report!(report, actor: admin)
      assert [] = Sharing.list_open_reports!(actor: admin)
    end
  end

  describe "hiding" do
    test "a hidden preset disappears for everyone but its author and admins" do
      author = register_user!()
      preset = share_preset!(author, %{title: "Spammy"})
      admin = register_admin!()
      visitor = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} = Sharing.hide_preset(preset, actor: author)
      Sharing.hide_preset!(preset, actor: admin)

      assert [] = Sharing.list_presets!(:watchdog_alarm, actor: visitor)
      assert {:error, _not_found} = Sharing.get_preset(preset.id, actor: visitor)
      assert {:ok, %{hidden: true}} = Sharing.get_preset(preset.id, actor: author)
      assert {:ok, _} = Sharing.get_preset(preset.id, actor: admin)

      assert {:error, _} = Sharing.post_comment(preset.id, "hello?", actor: visitor)
      assert {:error, _} = Sharing.like_preset(preset.id, actor: visitor)
    end

    test "a hidden preset's versions, comments and likes are hidden with it" do
      author = register_user!()
      preset = share_preset!(author)
      Sharing.post_comment!(preset.id, "nice", actor: register_user!())
      Sharing.like_preset!(preset.id, actor: register_user!())
      admin = register_admin!()
      Sharing.hide_preset!(preset, actor: admin)

      for actor <- [nil, register_user!()] do
        assert [] = Sharing.list_preset_versions!(preset.id, actor: actor)
        assert {:error, _not_found} = Sharing.get_preset_version(preset.id, 1, actor: actor)
        assert [] = Sharing.list_comments!(preset.id, actor: actor)
      end

      for actor <- [author, admin] do
        assert [%{number: 1}] = Sharing.list_preset_versions!(preset.id, actor: actor)
        assert [%{body: "nice"}] = Sharing.list_comments!(preset.id, actor: actor)
        assert %{like_count: 1} = Sharing.get_preset!(preset.id, actor: actor)
      end
    end

    test "admins can delete any preset or comment" do
      preset = share_preset!(register_user!())
      comment = Sharing.post_comment!(preset.id, "rude", actor: register_user!())
      admin = register_admin!()

      assert :ok = Sharing.remove_comment!(comment, actor: admin)
      assert :ok = Sharing.delete_preset!(preset, actor: admin)
    end
  end
end
