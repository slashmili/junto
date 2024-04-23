defmodule JuntoWeb.UserRegistrationLive do
  use JuntoWeb, :live_view

  alias Junto.Accounts
  alias Junto.Accounts.User

  def render(assigns) do
    ~H"""
    <div data-role="register-dialog" class="container mx-auto max-w-sm md:py-48 py-12">
      <div class="card shadow-xl w-100 bg-white/50 dark:bg-white/5 overflow-visible border dark:border-white/10 border-black/10">
        <.signup_card :if={not @check_otp} {assigns} />
        <.otp_card :if={@check_otp} {assigns} />
      </div>
    </div>
    """
  end

  defp otp_card(assigns) do
    ~H"""
    <button class="w-12 pt-2" phx-click="back-to-email">
      <.icon name="hero-chevron-left" class="" />
    </button>
    <div class="card-body">
      <h2 class="card-title">Enter Code</h2>
      Please enter the code digit we sent to <%= @user.email %>.
      <.signup_form
        for={@otp_form}
        id="otp_form"
        phx-submit="save_otp"
        phx-change="validate_otp"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
        phx-hook="InputOtpGroup"
      >
        <.input type="hidden" field={@otp_form[:email]} />
        <div class="hidden">
          <!-- had to do it since follow_trigger_action didn't notice the chagned :(-->
          <.input type="text" field={@otp_form[:otp_token]} />
        </div>
        <div class="flex flex-row gap-2">
          <.otp_input name="otp_1" />
          <.otp_input name="otp_2" />
          <.otp_input name="otp_3" />
          <.otp_input name="otp_4" />
          <.otp_input name="otp_5" />
          <.otp_input name="otp_6" />
        </div>
        <.error :if={@check_errors}>
          Invalid Code
        </.error>

        <:actions>
          <br />
          <.button id="btn-otp-submit" phx-disable-with="Creating account..." class="w-full max-w-sm">
            Create an account
          </.button>
        </:actions>
      </.signup_form>
    </div>
    """
  end

  defp otp_input(assigns) do
    ~H"""
    <div class="basis-1/6">
      <input
        type="text"
        name={@name}
        class="input input-bordered text-center w-12 h-12 input-otp"
        maxlength="1"
        autocomplete="off"
        required
      />
    </div>
    """
  end

  def signup_card(assigns) do
    ~H"""
    <div class="card-body">
      <h2 class="card-title">Welcome to Junto</h2>
      Register for an account
      <.signup_form
        for={@form}
        id="registration_form"
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
      </.signup_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false, check_otp: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("back-to-email", _, socket) do
    {:noreply,
     socket
     |> assign(check_otp: false)
     |> assign(check_errors: false)
     |> assign_form(socket.assigns.changeset)}
  end

  def handle_event("save_otp", %{"user" => user_params} = params, socket) do
    entered_otp = get_full_otp_code(params)

    changeset = Accounts.change_user_registration(%User{}, user_params)

    if entered_otp == socket.assigns.otp do
      {:ok, _user_token} =
        Accounts.validate_user_with_otp(socket.assigns.user, socket.assigns.otp_token)

      changeset = Accounts.change_user_registration(%User{}, user_params)

      {:noreply, socket |> assign(changeset: changeset, trigger_submit: true)}
    else
      {:noreply, socket |> assign(check_errors: true, changeset: changeset)}
    end
  end

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

        {:noreply,
         socket
         |> assign(
           check_otp: true,
           otp: otp_code,
           otp_token: otp_token,
           changeset: changeset,
           user: user
         )
         |> assign_otp_form(changeset)}

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

  def handle_event("validate_otp", %{"user" => user_params} = params, socket) do
    entered_otp = get_full_otp_code(params)

    changeset =
      if entered_otp == socket.assigns.otp do
        {:ok, _user_token} =
          Accounts.validate_user_with_otp(socket.assigns.user, socket.assigns.otp_token)

        user_params =
          Map.put(user_params, "otp_token", socket.assigns.otp_token)

        Accounts.change_user_registration(%User{}, user_params)
      else
        Accounts.change_user_registration(%User{}, user_params)
      end

    {:noreply, assign_otp_form(socket, changeset)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  defp assign_otp_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, otp_form: form, check_errors: false)
    else
      assign(socket, otp_form: form)
    end
  end

  defp get_full_otp_code(params) do
    Map.take(params, ["otp_1", "otp_2", "otp_3", "otp_4", "otp_5", "otp_6"])
    |> Map.values()
    |> Enum.join("")
  end

  defp create_otp_code do
    short_otp_code = :crypto.strong_rand_bytes(3) |> Base.encode16()
    long_token = short_otp_code <> :crypto.strong_rand_bytes(29)
    {short_otp_code, long_token}
  end
end
