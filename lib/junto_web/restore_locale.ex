defmodule JuntoWeb.RestoreLocale do
  @moduledoc false
  @known_locales Gettext.known_locales(JuntoWeb.Gettext)

  def on_mount(:default, params, session, socket) do
    locale_options = [&from_params/3, &from_browser/3, &default_locale/3]

    locale = Enum.find_value(locale_options, fn func -> func.(params, session, socket) end)

    if locale in @known_locales do
      Gettext.put_locale(JuntoWeb.Gettext, locale)
    end

    {:cont, socket}
  end

  defp from_params(params, _session, _socket) do
    case params do
      %{"locale" => locale} -> locale
      _ -> nil
    end
  end

  # TODO: implement from session
  # defp from_session(_params, session, _socket) do

  defp from_browser(_params, _session, socket) do
    case Phoenix.LiveView.get_connect_params(socket) do
      %{"navigator_language" => lang} when not is_nil(lang) ->
        String.slice(lang, 0, 2)

      _ ->
        nil
    end
  end

  defp default_locale(_, _, _) do
    Gettext.get_locale()
  end
end
