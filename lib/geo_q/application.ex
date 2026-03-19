defmodule GeoQ.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {GeoQ.Registry, []}
    ]

    opts = [strategy: :one_for_one, name: GeoQ.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
