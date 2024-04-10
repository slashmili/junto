defmodule Junto.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Junto.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Junto.Accounts.register_user()

    user
  end

  def user_otp_token_fixture(user, otp_token \\ nil) do
    {otp_token, user_token} = Junto.Accounts.UserToken.build_otp_token(user, "otp", otp_token)
    Junto.Repo.insert!(user_token)
    otp_token
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
