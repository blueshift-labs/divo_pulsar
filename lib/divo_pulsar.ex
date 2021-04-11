defmodule DivoPulsar do
  @moduledoc """
  Defines a pulsar broker in 'standalone' mode
  as a map compatible with divo for building a
  docker-compose file.
  """

  @behaviour Divo.Stack

  @doc """
  Implements the Divo Stack behaviour to take a
  keyword list of defined variables specific to
  the DivoPulsar stack and returns a map describing
  the service definition of Pulsar.

  ### Optional Configuration
  * `port`: The port on which the management API will be exposed to the host for making REST calls (for creating partitioned topics, posting schema, etc). The default port Pulsar uses for its REST API is 8080, which is commonly used by other services for web and REST accessibility and may be more likely to require an override if you are testing additional services alongside Pulsar simultaneously. This only effects the port exposed to the host; internally to the containerized service the API is listening on port 8080.

  * `ui_port`: The port on which the Pulsar dashboard will be exposed to the host. Configuring the UI port also enables the pulsar dashboard as part of the stack; this service is not enabled unless a port is specified. This only effects the port exposed to the host; internally to the containerized service the API is listening on port 80

  * `version`: The version of the Pulsar container image to create. Defaults to `latest`.
  """
  @impl Divo.Stack
  @spec gen_stack([tuple()]) :: map()
  def gen_stack(envars) do
    image_version = Keyword.get(envars, :version, "latest")
    api_port = Keyword.get(envars, :port, 8080)
    ui_port = Keyword.get(envars, :ui_port)
    start_period = Keyword.get(envars, :start_period, "60s")
    timeout = Keyword.get(envars, :timeout, "30s")
    interval = Keyword.get(envars, :interval, "5s")
    environment = Keyword.get(envars, :environment, [])

    pulsar_ports = ["6650:6650", exposed_ports(api_port, 8080)]

    healthcheck =
      healthcheck(envars)
      |> Enum.join(" ; ")

    pulsar_service = %{
      pulsar: %{
        image: "apachepulsar/pulsar:#{image_version}",
        ports: pulsar_ports,
        command: [
          "/bin/bash",
          "-c",
          "bin/apply-config-from-env.py ../../pulsar/conf/standalone.conf && bin/pulsar standalone"
        ],
        environment: environment,
        healthcheck: %{
          test: [
            "CMD-SHELL",
            healthcheck
          ],
          interval: interval,
          timeout: timeout,
          retries: 10,
          start_period: start_period
        }
      }
    }

    case ui_port == nil do
      true ->
        pulsar_service

      false ->
        dashboard_port = [exposed_ports(ui_port, 80)]

        Map.merge(pulsar_service, %{
          dashboard: %{
            image: "apachepulsar/pulsar-dashboard:latest",
            depends_on: ["pulsar"],
            ports: dashboard_port,
            environment: ["SERVICE_URL=http://pulsar:8080"]
          }
        })
    end
  end

  defp exposed_ports(external_port, internal_port) do
    to_string(external_port) <> ":" <> to_string(internal_port)
  end

  defp healthcheck(envars) do
    with {:ok, tenant} <- Keyword.fetch(envars, :tenant),
         {:ok, namespace} <- Keyword.fetch(envars, :namespace),
         {:ok, topics} <- Keyword.fetch(envars, :topics) do
      ["bin/pulsar-admin tenants create #{tenant}"] ++
        ["bin/pulsar-admin namespaces create #{tenant}/#{namespace}"] ++
        (topics
         |> Enum.map(
           &["bin/pulsar-admin topics create persistent://#{tenant}/#{namespace}/#{&1}"]
         )) ++
        ["bin/pulsar-admin topics list #{tenant}/#{namespace}"]
    else
      _ ->
        ["bin/pulsar-admin tenants list"]
    end
  end
end
