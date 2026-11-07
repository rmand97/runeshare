defmodule Runeshare.Accounts.DeleteAccountTest do
  use Runeshare.DataCase, async: true

  alias AshStorage.Service.Test, as: Store
  alias Runeshare.Accounts
  alias Runeshare.Accounts.UserIdentity
  alias Runeshare.Sharing

  defp key("http://test.local/storage/" <> key), do: key

  # Identities are only readable inside the auth flow.
  defp identities_for(user) do
    UserIdentity
    |> Ash.read!(context: %{private: %{ash_authentication?: true}})
    |> Enum.filter(&(&1.user_id == user.id))
  end

  describe "delete_account" do
    test "removes the user and everything they shared, and nothing of anyone else's" do
      user = register_user!()
      other = register_user!()

      own = share_preset!(user, %{cover_image: cover_image()})
      cover_key = key(Sharing.get_preset!(own.id).cover_image_url)
      Sharing.edit_preset!(own, %{title: "Second version"}, actor: user)

      theirs = share_preset!(other)
      Sharing.like_preset!(theirs.id, actor: user)
      Sharing.post_comment!(theirs.id, "mine", actor: user)
      Sharing.report_preset!(theirs.id, :spam, actor: user)
      kept_comment = Sharing.post_comment!(theirs.id, "theirs", actor: other)
      Sharing.like_preset!(own.id, actor: other)

      assert Enum.any?(identities_for(user))
      assert Store.exists?(cover_key)

      assert :ok = Accounts.delete_account(user, actor: user)

      assert {:error, _} = Accounts.get_user(user.id)
      assert Enum.empty?(identities_for(user))
      assert {:error, _} = Sharing.get_preset(own.id)
      refute Store.exists?(cover_key)

      after_delete = Sharing.get_preset!(theirs.id)
      assert after_delete.like_count == 0
      assert [%{id: id}] = Sharing.list_comments!(theirs.id)
      assert id == kept_comment.id
      assert [] = Sharing.list_open_reports!(actor: register_admin!())
    end

    test "nobody can delete someone else's account, and visitors can't delete any" do
      user = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.delete_account(user, actor: register_user!())

      assert {:error, %Ash.Error.Forbidden{}} = Accounts.delete_account(user)
      assert {:ok, _} = Accounts.get_user(user.id)
    end

    test "signing in again afterwards starts a new, empty account" do
      user = register_user!(email: "returning@example.com")
      share_preset!(user)
      Accounts.delete_account!(user, actor: user)

      again = register_user!(email: "returning@example.com")

      assert again.id != user.id
      assert [] = Sharing.list_my_presets!(actor: again, page: false)
    end
  end

  describe "provider OAuth tokens" do
    test "are not stored on sign-in" do
      {:ok, user} =
        register_with(:github, %{
          "sub" => "gh-1",
          "preferred_username" => "octo",
          "email" => "tokens@example.com",
          "email_verified" => true
        })

      assert [identity] = identities_for(user)
      assert identity.strategy == "github"
      assert identity.access_token == nil
      assert identity.refresh_token == nil
    end
  end
end
