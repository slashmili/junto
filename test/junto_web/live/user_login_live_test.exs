defmodule JuntoWeb.UserLoginLiveTest do
  use JuntoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Junto.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      assert has_element?(lv, "[data-role=login-dialog]")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/log_in")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end
  end

  describe "user login" do
    test "enter email and expect to see otp form", %{conn: conn} do
      user = user_fixture(confirmed_at: DateTime.utc_now())

      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      lv
      |> form("#login-form", user: %{email: user.email})
      |> render_submit()

      assert has_element?(lv, "#otp-form")
    end

    test "verify the account and logs the user in", %{conn: conn} do
      user = user_fixture(confirmed_at: DateTime.utc_now())
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      lv
      |> form("#login-form", user: %{email: user.email})
      |> render_submit()

      {otp_code, otp_token} = Junto.AccountsFixtures.fetch_otp_token()

      params = [
        otp: [
          String.at(otp_code, 0),
          String.at(otp_code, 1),
          String.at(otp_code, 2),
          String.at(otp_code, 3),
          String.at(otp_code, 4),
          String.at(otp_code, 5)
        ],
        user: %{otp_token: otp_token, email: user.email}
      ]

      form = form(lv, "#otp-form", params)
      render_submit(form, %{user: %{otp_token: otp_token}})
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "renders error when invalid OTP is entered", %{conn: conn} do
      user = user_fixture(confirmed_at: DateTime.utc_now())
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      lv
      |> form("#login-form", user: %{email: user.email})
      |> render_submit()

      {_otp_code, otp_token} = Junto.AccountsFixtures.fetch_otp_token()

      params = [otp: [0, 0, 0, 0, 0, 0], user: %{otp_token: otp_token, email: user.email}]

      form = form(lv, "#otp-form", params)
      render_submit(form, %{user: %{otp_token: otp_token}})

      assert has_element?(lv, "[data-role=invalid-otp-code-error]")
    end

    test "renders OTP form when an none existing email is entered", %{conn: conn} do
      email = "foo@bar.com"
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      lv
      |> form("#login-form", user: %{email: email})
      |> render_submit()


      assert has_element?(lv, "#otp-form")
    end
  end
end
