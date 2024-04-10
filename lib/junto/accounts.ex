defmodule Junto.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Junto.Repo

  alias Junto.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_otp_code(user, &url(~p"/users/otp-token/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_otp_code(confirmed_user, &url(~p"/users/otp-token/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_otp_code(user, confirmation_otp_url_fun, otp_token \\ nil) do
    # TODO: Delete any unused otp token

    {encoded_token, user_token} =
      UserToken.build_otp_token(user, "otp", otp_token)

    Repo.insert!(user_token)
    UserNotifier.deliver_otp_code(user, otp_token, confirmation_otp_url_fun.(encoded_token))
  end

  def validate_user_with_otp(user, otp_token) do
    with {:ok, query} <- UserToken.verify_otp_token_query(user, otp_token),
         %UserToken{} = user_token <- Repo.one(query) do
      {:ok, user_token}
    else
      _ -> :error
    end
  end

  def confirm_user_with_otp(user, otp_token) do
    with {:ok, query} <- UserToken.verify_otp_token_query(user, otp_token),
         %UserToken{} = _user_token <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ ->
        :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["otp"]))
  end

  def active_user?(user) do
    user.confirmed_at != nil
  end
end
