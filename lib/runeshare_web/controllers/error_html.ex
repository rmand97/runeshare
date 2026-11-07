defmodule RuneshareWeb.ErrorHTML do
  @moduledoc """
  Error pages for HTML requests (see `render_errors` in config/config.exs).
  One standalone page for every status: the site's stylesheet, a short
  explanation and links back in. No layout and no scripts, since an error can
  happen before the router has set the session or the CSP nonce.
  """
  use RuneshareWeb, :html

  @spec render(String.t(), map()) :: Phoenix.LiveView.Rendered.t()
  def render(template, assigns) do
    status = template |> String.split(".") |> hd() |> String.to_integer()

    assigns
    |> Map.put(:status, status)
    |> Map.put(:title, Phoenix.Controller.status_message_from_template(template))
    |> Map.put(:message, message(status))
    |> error_page()
  end

  defp message(404),
    do:
      "There's nothing here. The preset may have been deleted or hidden, or the link has a typo."

  defp message(400), do: "That link looks broken. Check it, or start again from the front page."

  defp message(status) when status >= 500,
    do: "Something went wrong on our side. Please try again in a moment."

  defp message(_status), do: "That didn't work. Start again from the front page."

  attr :status, :integer, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true

  defp error_page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" data-theme="dark">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
        <title>{@title} · RuneShare</title>
        <link rel="icon" href={~p"/favicon.svg"} type="image/svg+xml" />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body class="flex min-h-screen items-center justify-center bg-base-300 p-4 font-sans text-base-content antialiased">
        <main class="w-full max-w-md space-y-4 rounded-box border border-base-content/10 bg-base-100 p-6 text-center">
          <a
            href="/"
            class="inline-flex items-center gap-1.5 font-display text-sm font-bold tracking-[0.12em] uppercase"
          >
            <.icon name="hero-sparkles" class="size-5 text-primary" />
            <span>Rune<span class="text-primary">Share</span></span>
          </a>
          <p class="font-mono text-5xl font-bold text-primary">{@status}</p>
          <h1 class="font-display text-xl font-bold tracking-wide uppercase">{@title}</h1>
          <p class="text-sm text-base-content/75">{@message}</p>
          <nav class="flex flex-wrap justify-center gap-2 pt-2" aria-label="Back into RuneShare">
            <a href="/" class="btn btn-primary btn-sm">Front page</a>
            <a href="/watchdog" class="btn btn-outline btn-sm">Watchdog alarms</a>
            <a href="/tile-markers" class="btn btn-outline btn-sm">Tile markers</a>
          </nav>
        </main>
      </body>
    </html>
    """
  end
end
