defmodule JuntoWeb.UserLive.OtpFormComponent do
  use JuntoWeb, :live_component

  alias Junto.Accounts
  alias Junto.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <button class="w-12 pt-2" phx-click="back-to-email">
        <.icon name="hero-chevron-left" class="" />
      </button>
      <div class="card-body">
        <h2 class="card-title">Enter Code</h2>
        Please enter the code digit we sent to <%= @user.email %>.
        <.simple_form
          for={@otp_form}
          id={@id}
          phx-target={@myself}
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={@action}
          method="post"
          phx-hook="InputOtpGroup"
        >
          <.input type="hidden" field={@otp_form[:email]} />
          <div class="hidden">
            <!-- had to do it since follow_trigger_action didn't notice the chagned :(-->
            <.input type="text" field={@otp_form[:otp_token]} />
          </div>
          <div class="flex flex-row gap-2" phx-update="ignore" id={"#{@id}-otp-input-group"}>
            <.otp_input name="otp[]" />
            <.otp_input name="otp[]" />
            <.otp_input name="otp[]" />
            <.otp_input name="otp[]" />
            <.otp_input name="otp[]" />
            <.otp_input name="otp[]" />
          </div>
          <.error :if={@check_errors}>
            Invalid Code
          </.error>

          <:actions>
            <br />
            <.button
              id="btn-otp-submit"
              phx-disable-with="Creating account..."
              class="w-full max-w-sm"
            >
              Create an account
            </.button>
          </:actions>
        </.simple_form>
      </div>
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

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    socket = assign_otp_form(socket, assigns.changeset)
    socket = assign(socket, trigger_submit: false)
    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params, "otp" => otps}, socket) do
    entered_otp = Enum.join(otps, "")

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

  @impl true
  def handle_event("save", %{"user" => user_params, "otp" => otps}, socket) do
    entered_otp = Enum.join(otps, "")

    changeset = Accounts.change_user_registration(%User{}, user_params)

    if entered_otp == socket.assigns.otp do
      {:ok, _user_token} =
        Accounts.validate_user_with_otp(socket.assigns.user, socket.assigns.otp_token)

      user_params =
        Map.put(user_params, "otp_token", socket.assigns.otp_token)

      changeset = Accounts.change_user_registration(%User{}, user_params)

      {:noreply, socket |> assign(changeset: changeset, trigger_submit: true)}
    else
      {:noreply, socket |> assign(check_errors: true, changeset: changeset)}
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
end
