defmodule Runeshare.ActionLogTest do
  use Runeshare.DataCase, async: true

  import ExUnit.CaptureLog

  alias Runeshare.Sharing

  describe "one line per action" do
    test "a share logs the action, actor id, record id and duration — not the email" do
      author = register_user!(email: "secret-author@example.com")

      {preset, log} = with_log(fn -> share_preset!(author) end)

      assert log =~ "[info] Sharing.Preset.share ok in "
      assert log =~ "actor=user:#{author.id}"
      assert log =~ "id=#{preset.id}"
      refute log =~ "secret-author"
      refute log =~ preset.content
    end

    test "a forbidden edit is a warning naming the actor" do
      preset = share_preset!(register_user!())
      intruder = register_user!()

      log =
        capture_log(fn ->
          assert {:error, %Ash.Error.Forbidden{}} =
                   Sharing.edit_preset(preset, %{title: "Mine now"}, actor: intruder)
        end)

      assert log =~ "[warning] Sharing.Preset.edit forbidden in "
      assert log =~ "actor=user:#{intruder.id} errors=[Forbidden.Policy]"
    end

    test "invalid input names the field and rule, never the rejected value" do
      author = register_user!()
      attrs = %{kind: :watchdog_alarm, title: "No", content: "not-a-watchdog-export-value"}

      log =
        capture_log(fn ->
          assert {:error, %Ash.Error.Invalid{}} = Sharing.share_preset(attrs, actor: author)
        end)

      assert log =~ "[info] Sharing.Preset.share invalid in "
      assert log =~ "InvalidAttribute(title): length must be greater than or equal to 3"
      refute log =~ "not-a-watchdog-export-value"
    end

    test "anonymous attempts are logged as anon" do
      attrs = %{kind: :tile_marker, title: "Anon tiles", content: tile_marker_token()}
      log = capture_log(fn -> Sharing.share_preset(attrs) end)

      assert log =~ "Sharing.Preset.share forbidden"
      assert log =~ "actor=anon"
    end

    test "moderation actions carry the moderator and the preset" do
      preset = share_preset!(register_user!())
      admin = register_admin!()

      log = capture_log(fn -> Sharing.hide_preset!(preset, actor: admin) end)

      assert log =~ "[info] Sharing.Preset.hide ok in "
      assert log =~ "actor=user:#{admin.id} id=#{preset.id}"
      refute log =~ "admin@example.com"
    end

    test "reads stay below info" do
      preset = share_preset!(register_user!())

      refute capture_log(fn -> Sharing.get_preset!(preset.id) end) =~ "Sharing.Preset.read"
    end
  end

  describe "rate limits" do
    test "hitting one logs a warning with the actor" do
      preset = share_preset!(register_user!())
      chatty = register_user!()
      for n <- 1..10, do: Sharing.post_comment!(preset.id, "comment #{n}", actor: chatty)

      log = capture_log(fn -> Sharing.post_comment(preset.id, "one too many", actor: chatty) end)

      assert log =~ "[warning] rate limit hit: Runeshare.Sharing.Comment"
      assert log =~ "actor=user:#{chatty.id}"
      assert log =~ "Sharing.Comment.post invalid"
    end
  end

  describe "query-based bulk destroys" do
    # Ash never opens a tracer span for these; the notifier logs them instead.
    test "an unlike is still logged with actor and record" do
      preset = share_preset!(register_user!())
      fan = register_user!()
      like = Sharing.like_preset!(preset.id, actor: fan)

      log = capture_log(fn -> Sharing.unlike_preset!(preset.id, fan.id, actor: fan) end)

      assert log =~ "Sharing.Like.unlike ok actor=user:#{fan.id} id=#{like.id}"
    end
  end
end
