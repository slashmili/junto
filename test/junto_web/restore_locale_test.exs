defmodule JuntoWeb.RestoreLocaleTest do
  use JuntoWeb.ConnCase, async: true

  alias JuntoWeb.RestoreLocale, as: SUT

  setup do
    socket = %Phoenix.LiveView.Socket{private: %{connect_params: %{}}}
    {:ok, %{socket: socket}}
  end

  describe "detects user's preferred locale" do
    test "returns default locale as fallback", %{socket: socket} do
      assert {:cont, _} = SUT.on_mount(:default, %{}, %{}, socket)
      assert Gettext.get_locale(JuntoWeb.Gettext) == "en"
    end

    test "returns locale based on browser" do
      # only works when page is connected
      socket = %Phoenix.LiveView.Socket{
        transport_pid: self(),
        private: %{
          connect_params: %{
            "navigator_language" => "de-DE"
          }
        }
      }

      assert {:cont, _} = SUT.on_mount(:default, %{}, %{}, socket)
      assert Gettext.get_locale(JuntoWeb.Gettext) == "de"
    end

    test "returns locale based on params", %{socket: socket} do
      assert {:cont, _} = SUT.on_mount(:default, %{"locale" => "de"}, %{}, socket)
      assert Gettext.get_locale(JuntoWeb.Gettext) == "de"
    end

    @tag :skip
    test "returns locale based on session", %{socket: socket} do
      assert {:cont, _} = SUT.on_mount(:default, %{}, %{"some_session" => ""}, socket)
      assert Gettext.get_locale(JuntoWeb.Gettext) == "de"
    end



    test "falls back to en when locale is invalid", %{socket: socket} do
      assert {:cont, _} = SUT.on_mount(:default, %{"locale" => "fo"}, %{}, socket)
      assert Gettext.get_locale(JuntoWeb.Gettext) == "en"
    end
  end
end
