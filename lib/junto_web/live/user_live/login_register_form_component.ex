defmodule JuntoWeb.UserLive.LoginRegisterFormComponent do
  use JuntoWeb, :live_component

  alias Junto.Accounts
  alias Junto.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card-body">
      <h2 class="card-title">Welcome to Junto</h2>
      Register for an account
      <.simple_form
        for={@form}
        id={@id}
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
        method="post"
      >
        <.input_center
          field={@form[:email]}
          type="email"
          label="Email"
          placeholder="you@email.com"
          icon="hero-envelope-solid"
          required
          autocomplete="email webauthn"
        />
        <:actions>
          <.button phx-disable-with="Creating account..." class="w-full max-w-sm">
            Continue with email
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = assigns.changeset || Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(check_errors: false)
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    {otp_code, otp_token} = create_otp_code()

    case register_or_return_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_otp_code(
            user,
            &url(~p"/users/confirm/#{&1}"),
            otp_token
          )

        changeset = Accounts.change_user_registration(user)

        otp_token = Base.url_encode64(otp_token, padding: false)

        params = %{
          check_otp: true,
          otp: otp_code,
          otp_token: otp_token,
          changeset: changeset,
          user: user
        }

        notify_parent({:valid_user, params})

        {:noreply,
         socket
         |> assign(
           check_otp: true,
           otp: otp_code,
           otp_token: otp_token,
           changeset: changeset,
           user: user
         )}

      {:error, :active_user} ->
        changeset = Accounts.change_user_registration(%User{}, user_params)

        {:noreply,
         socket
         |> assign(
           check_otp: true,
           otp: otp_code,
           otp_token: otp_token,
           changeset: changeset,
           user: %{email: user_params["email"]}
         )
         |> assign_otp_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  defp create_otp_code do
    short_otp_code = :crypto.strong_rand_bytes(3) |> Base.encode16()
    long_token = short_otp_code <> :crypto.strong_rand_bytes(29)
    {short_otp_code, long_token}
  end

  defp register_or_return_user(user_params) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ecto.Changeset{errors: [email: {"has already been taken", _}]}} ->
        user = Accounts.get_user_by_email(user_params["email"])

        if Accounts.active_user?(user) do
          {:error, :active_user}
        else
          {:ok, user}
        end
    end
  end

  defp assign_otp_form(socket, changeset) do
    send(self(), {:assign_otp_form, changeset})
    socket
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
