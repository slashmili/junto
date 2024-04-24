defmodule JuntoWeb.UserRegistrationLiveTest do
  use JuntoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Junto.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      assert has_element?(lv, "[data-role=register-dialog]")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration-form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "enters email and expect to see otp form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration-form", user: valid_user_attributes(email: email))
      render_submit(form)

      assert has_element?(lv, "#otp-form")
    end

    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      form = form(lv, "#registration-form", user: valid_user_attributes(email: email))
      render_submit(form)

      import Swoosh.TestAssertions

      test_pid = self()

      assert_email_sent(fn email ->
        otp_pattern = ~r/One-Time-Code:\s*\n\s*(\w+)\s*\n/
        token_pattern = ~r{confirm/([\w-]+)\n\n}

        [[_, otp_code]] = Regex.scan(otp_pattern, email.text_body)

        [[_, otp_token]] = Regex.scan(token_pattern, email.text_body)
        send(test_pid, {:otp_code, otp_code})
        send(test_pid, {:otp_token, otp_token})
      end)

      assert_received({:otp_code, otp_code})
      assert_received({:otp_token, otp_token})

      params = [
        otp: [
          String.at(otp_code, 0),
          String.at(otp_code, 1),
          String.at(otp_code, 2),
          String.at(otp_code, 3),
          String.at(otp_code, 4),
          String.at(otp_code, 5)
        ],
        user: %{otp_token: otp_token, email: email}
      ]

      form = form(lv, "#otp-form", params)
      render_submit(form, %{user: %{otp_token: otp_token}})
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      assert html_response(conn, 200)
    end

    test "renders otp form for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      lv
      |> form("#registration-form",
        user: %{"email" => user.email}
      )
      |> render_submit()

      assert has_element?(lv, "#otp-form")
    end
  end
end
