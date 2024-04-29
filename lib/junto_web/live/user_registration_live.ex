defmodule JuntoWeb.UserRegistrationLive do
  use JuntoWeb, :live_view
  require Logger

  alias Junto.Accounts

  defp register_action(user_params) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ecto.Changeset{errors: [email: {"has already been taken", _}]}} ->
        user = Accounts.get_user_by_email(user_params["email"])

        if Accounts.active_user?(user) do
          {:error, :register_active_user}
        else
          {:ok, user}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <div data-role="register-dialog" class="login-register-dialog">
      <div class="card">
        <.live_component
          :if={not @check_otp}
          module={JuntoWeb.UserLive.LoginRegisterFormComponent}
          id="registration-form"
          changeset={@changeset}
          form={@form}
          page_action={&register_action/1}
          submit_loading="Creating account..."
        >
          <:subtitle>
            <%= gettext "Register for an account" %>
          </:subtitle>
        </.live_component>

        <.live_component
          :if={@check_otp}
          action={~p"/users/log_in?_action=registered"}
          module={JuntoWeb.UserLive.OtpFormComponent}
          changeset={@changeset}
          user={@user}
          otp={@otp}
          otp_token={@otp_token}
          id="otp-form"
        />
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket = assign(socket, check_otp: false, changeset: nil)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("back-to-email", _, socket) do
    {:noreply, assign(socket, check_otp: false)}
  end

  def handle_info({JuntoWeb.UserLive.LoginRegisterFormComponent, {:valid_user, params}}, socket) do
    params_to_set = [
      user: params.user,
      otp: params.otp,
      check_otp: params.check_otp,
      changeset: params.changeset,
      otp_token: params.otp_token
    ]

    {:noreply, assign(socket, params_to_set)}
  end

  def handle_info({JuntoWeb.UserLive.LoginRegisterFormComponent, {:active_user, params}}, socket) do
    params_to_set = [
      user: params.user,
      otp: "",
      check_otp: params.check_otp,
      changeset: params.changeset,
      otp_token: ""
    ]

    {:noreply, assign(socket, params_to_set)}
  end

  def handle_info(event, socket) do
    Logger.debug("Unhandled handle_info message: #{inspect([event, socket])}")
    {:noreply, socket}
  end
end
