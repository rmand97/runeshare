defmodule Runeshare.AccountsTest do
  use Runeshare.DataCase, async: true

  alias Runeshare.Accounts

  describe "Google sign-in" do
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

  describe "GitHub, Discord and Twitch sign-in" do
    # Assent's normalised user_info for each provider, minus anything we don't read.
    defp claims(:github, email, verified),
      do: %{
        "sub" => "gh-#{email}",
        "name" => nil,
        "preferred_username" => "octo-zezima",
        "email" => email,
        "email_verified" => verified,
        "picture" => "https://avatars.githubusercontent.com/u/1"
      }

    defp claims(:discord, email, verified),
      do: %{
        "sub" => "dc-#{email}",
        "preferred_username" => "zezima",
        "email" => email,
        "email_verified" => verified,
        "picture" => "https://cdn.discordapp.com/avatars/1/abc"
      }

    defp claims(:twitch, email, verified),
      do: %{
        "sub" => "tw-#{email}",
        "preferred_username" => "ZezimaLive",
        "email" => email,
        "email_verified" => verified,
        "picture" => "https://static-cdn.jtvnw.net/user-default-pictures/x.png"
      }

    for provider <- [:github, :discord, :twitch] do
      test "#{provider} creates a user, named by username when there's no full name" do
        provider = unquote(provider)

        assert {:ok, user} =
                 register_with(provider, claims(provider, "#{provider}@example.com", true))

        assert to_string(user.email) == "#{provider}@example.com"
        assert user.name == claims(provider, "", true)["preferred_username"]
        assert user.avatar_url == claims(provider, "", true)["picture"]
      end

      test "#{provider} refuses an unverified email" do
        provider = unquote(provider)
        register_user!(email: "victim-#{provider}@example.com")

        assert {:error, %Ash.Error.Invalid{} = error} =
                 register_with(
                   provider,
                   claims(provider, "victim-#{provider}@example.com", false)
                 )

        assert Exception.message(error) =~ "hasn't verified this account's email"
      end
    end

    test "the same verified email signs into one account from every provider" do
      google_user = register_user!(email: "everywhere@example.com", name: "Zezima")

      for provider <- [:github, :discord, :twitch] do
        assert {:ok, %{id: id}} =
                 register_with(provider, claims(provider, "everywhere@example.com", true))

        assert id == google_user.id
      end
    end

    test "an account without an email is refused (GitHub with no verified address)" do
      assert {:error, %Ash.Error.Invalid{}} =
               register_with(:github, claims(:github, nil, true))
    end

    test "a Discord user without an avatar gets none, not a broken image URL" do
      info = %{
        claims(:discord, "noavatar@example.com", true)
        | "picture" => "https://cdn.discordapp.com/avatars/1/"
      }

      assert {:ok, %{avatar_url: nil}} = register_with(:discord, info)
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
