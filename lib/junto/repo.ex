defmodule Junto.Repo do
  use Ecto.Repo,
    otp_app: :junto,
    adapter: Ecto.Adapters.Postgres
end
