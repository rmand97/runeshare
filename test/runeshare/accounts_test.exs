defmodule Runeshare.AccountsTest do
  use Runeshare.DataCase, async: true

  alias Runeshare.Accounts

  describe "register_with_google" do
    test "creates a user from Google's claims" do
      user = register_user!(email: "zezima@example.com", name: "Zezima")

      assert to_string(user.email) == "zezima@example.com"
      assert user.name == "Zezima"
      assert user.avatar_url =~ "https://example.com/avatar/"
    end

    test "signing in again returns the same user and keeps their chosen name" do
      first = register_user!(email: "same@example.com", name: "Original")
      Accounts.update_profile!(first, %{name: "Chosen name"}, actor: first)

      second = register_user!(email: "same@example.com", name: "Google name")

      assert first.id == second.id
      assert second.name == "Chosen name"
    end

    test "refuses an email Google hasn't verified, so it can't take over an existing account" do
      register_user!(email: "victim@example.com")

      assert {:error, %Ash.Error.Invalid{}} =
               register_user(email: "victim@example.com", email_verified: false)

      assert {:error, %Ash.Error.Invalid{}} =
               register_user(email: "admin@example.com", email_verified: false)
    end
  end

  describe "update_profile" do
    test "a user can rename themselves but not someone else" do
      user = register_user!()
      other = register_user!()

      assert %{name: "Zezima"} = Accounts.update_profile!(user, %{name: "Zezima"}, actor: user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_profile(other, %{name: "Hijacked"}, actor: user)
    end
  end
end
