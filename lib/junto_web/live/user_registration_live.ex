defmodule JuntoWeb.UserRegistrationLive do
  use JuntoWeb, :live_view
  require Logger

  def render(assigns) do
    ~H"""
    <div data-role="register-dialog" class="container mx-auto max-w-sm md:py-48 py-12">
      <div class="card shadow-xl w-100 bg-white/50 dark:bg-white/5 overflow-visible border dark:border-white/10 border-black/10">
        <.live_component
          :if={not @check_otp}
          module={JuntoWeb.UserLive.LoginRegisterFormComponent}
          id="registration-form"
          changeset={@changeset}
          form={@form}
        />

        <.live_component
          :if={@check_otp}
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

  def handle_info(event, socket) do
    Logger.debug("Unhandled handle_info message: #{inspect([event, socket])}")
    {:noreply, socket}
  end
end
