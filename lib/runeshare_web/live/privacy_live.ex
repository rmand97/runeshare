defmodule RuneshareWeb.PrivacyLive do
  @moduledoc """
  The privacy policy: what RuneShare stores, why, who processes it, and how to
  get it removed. Keep it in step with the data the resources actually hold.
  """

  use RuneshareWeb, :live_view

  import RuneshareWeb.PresetComponents, only: [breadcrumbs: 1]

  @updated ~D[2026-11-07]
  @contact "raflnatorr.gaming@gmail.com"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Privacy",
        updated: @updated,
        contact: @contact,
        og: %{
          title: "Privacy — RuneShare",
          description: "What RuneShare stores about you, why, and how to delete it.",
          url: url(~p"/privacy")
        }
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} width="max-w-3xl">
      <div>
        <.breadcrumbs crumbs={[{"Home", ~p"/"}, {"Privacy", nil}]} />
        <h1 class="font-display text-xl font-bold tracking-wide uppercase sm:text-2xl">
          Privacy
        </h1>
        <p class="text-xs text-base-content/65">
          Last updated {Calendar.strftime(@updated, "%-d %B %Y")}
        </p>
      </div>

      <article
        id="privacy"
        class="space-y-5 rounded-box border border-base-content/10 bg-base-100 p-4 text-sm/relaxed text-base-content/85 sm:p-6 [&_a]:link [&_a]:link-primary [&_h2]:font-display [&_h2]:text-base [&_h2]:font-bold [&_h2]:tracking-wide [&_h2]:text-base-content [&_h2]:uppercase [&_li]:ml-4 [&_ul]:list-disc [&_ul]:space-y-1"
      >
        <p>
          RuneShare is a small community site for sharing RuneScape 3 plugin setups. It keeps as
          little about you as it can, never sells or shares it for advertising, and has no
          analytics, ads or third-party trackers.
        </p>

        <section class="space-y-2">
          <h2>Who runs it</h2>
          <p>
            RuneShare is run privately by its developer, who decides what is stored and why.
            Questions or requests about your data: <a href={"mailto:" <> @contact}>{@contact}</a>.
          </p>
        </section>

        <section class="space-y-2">
          <h2>What we store</h2>
          <p>When you browse without signing in:</p>
          <ul>
            <li>
              One cookie, <code>_runeshare_key</code>, holding a random visitor id (so a copy is
              counted once per visitor) and a security token for forms. It's needed for the site
              to work, so there's no cookie banner.
            </li>
            <li>Your light/dark theme choice, in your browser's local storage only.</li>
          </ul>
          <p>When you sign in with Google, GitHub, Discord or Twitch, we also store:</p>
          <ul>
            <li>
              Your <strong>email address</strong>, as the provider reports it. Only you can see
              it. It links your sign-ins: the same verified email is the same account whichever
              provider you use.
            </li>
            <li>
              Your <strong>display name</strong> and <strong>avatar</strong> link, shown next to
              what you share. The name starts as your name on the provider; you can change it on
              your account page.
            </li>
            <li>
              Which providers you've signed in with and their id for your account there. We don't
              keep the provider's access tokens, and we can't see your password.
            </li>
            <li>Sign-in session records, so you stay signed in. They expire on their own.</li>
          </ul>
          <p>And what you choose to put on the site:</p>
          <ul>
            <li>
              Presets you share (with every saved version), their cover images and tags, and your
              comments. These are public, with your display name.
            </li>
            <li>
              Your likes, and which presets you've copied while signed in. Others only see them as
              counts; your list of liked presets is visible only to you.
            </li>
            <li>Reports you file, seen only by moderators.</li>
          </ul>
          <p>
            Server logs record requests (which page, when, and your user id if signed in) to find
            and fix problems. They don't contain your email.
          </p>
        </section>

        <section class="space-y-2">
          <h2>Who processes it</h2>
          <ul>
            <li>
              <strong>Fly.io</strong> hosts the site and its database, in Amsterdam (EU).
            </li>
            <li><strong>Tigris</strong> stores cover images and serves them publicly.</li>
            <li>
              <strong>Google, GitHub, Discord or Twitch</strong>, whichever you sign in with, under
              their own privacy policies. We only receive your profile and email from them.
            </li>
          </ul>
        </section>

        <section class="space-y-2">
          <h2>How long we keep it</h2>
          <p>
            Until you delete it. Deleting a preset or comment removes it straight away; deleting
            your account removes everything below. Database backups are kept for 14 days, so
            deleted data disappears from those within two weeks.
          </p>
        </section>

        <section class="space-y-2">
          <h2>Your choices</h2>
          <ul>
            <li>
              <strong>Delete your account</strong>
              on <.link navigate={~p"/account"}>your account page</.link>. It removes your account,
              your presets with their versions and cover images, your comments, likes and reports,
              straight away. Copy counts stay, but no longer point to you.
            </li>
            <li>Change your display name on the same page.</li>
            <li>Delete any single preset or comment from its page.</li>
            <li>
              For a copy of your data, or anything else about privacy, email <a
                id="privacy-contact"
                href={"mailto:" <> @contact}
              >{@contact}</a>.
            </li>
          </ul>
          <p>
            You have the right to access, correct and delete your data, and to complain to your
            data protection authority (in Denmark, Datatilsynet).
          </p>
        </section>

        <p class="text-xs text-base-content/65">
          RuneShare is community-made and not affiliated with Jagex. RuneScape is a trademark of
          Jagex Ltd.
        </p>
      </article>
    </Layouts.app>
    """
  end
end
