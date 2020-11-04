defmodule DivoPulsarTest do
  use ExUnit.Case

  describe "produces a pulsar stack map" do
    test "with no specified environment variables" do
      expected = %{
        pulsar: %{
          image: "apachepulsar/pulsar:latest",
          ports: ["6650:6650", "8080:8080"],
          command: ["bin/pulsar", "standalone"],
          healthcheck: %{
            test: [
              "CMD-SHELL",
              "bin/pulsar-admin tenants list"
            ],
            interval: "5s",
            timeout: "30s",
            retries: 10,
            start_period: "60s"
          }
        }
      }

      actual = DivoPulsar.gen_stack([])

      assert actual == expected
    end

    test "produces a pulsar stack map with supplied environment config" do
      expected = %{
        pulsar: %{
          image: "apachepulsar/pulsar:v2",
          ports: ["6650:6650", "8079:8080"],
          command: ["bin/pulsar", "standalone"],
          healthcheck: %{
            test: [
              "CMD-SHELL",
              "bin/pulsar-admin tenants list"
            ],
            interval: "5s",
            timeout: "30s",
            retries: 10,
            start_period: "60s"
          }
        },
        dashboard: %{
          image: "apachepulsar/pulsar-dashboard:latest",
          depends_on: ["pulsar"],
          ports: ["80:80"],
          environment: ["SERVICE_URL=http://pulsar:8080"]
        }
      }

      actual =
        DivoPulsar.gen_stack(
          port: 8079,
          ui_port: 80,
          version: "v2"
        )

      assert actual == expected
    end

    test "produces a pulsar stack map with created topics " do
      expected = %{
        pulsar: %{
          image: "apachepulsar/pulsar:v2",
          ports: ["6650:6650", "8079:8080"],
          command: ["bin/pulsar", "standalone"],
          healthcheck: %{
            test: [
              "CMD-SHELL",
              "bin/pulsar-admin tenants create indexing ; bin/pulsar-admin namespaces create indexing/test ; bin/pulsar-admin topics create persistent://indexing/test/raw.json ; bin/pulsar-admin topics create persistent://indexing/test/sanitized.json ; bin/pulsar-admin topics list indexing/test"
            ],
            interval: "3s",
            timeout: "15s",
            retries: 10,
            start_period: "45s"
          }
        },
        dashboard: %{
          image: "apachepulsar/pulsar-dashboard:latest",
          depends_on: ["pulsar"],
          ports: ["80:80"],
          environment: ["SERVICE_URL=http://pulsar:8080"]
        }
      }

      actual =
        DivoPulsar.gen_stack(
          port: 8079,
          ui_port: 80,
          version: "v2",
          tenant: "indexing",
          namespace: "test",
          topics: ["raw.json", "sanitized.json"],
          start_period: "45s",
          interval: "3s",
          timeout: "15s"
        )

      assert actual == expected
    end
  end
end
