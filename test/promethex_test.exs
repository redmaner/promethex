defmodule PromethexTest do
  use ExUnit.Case

  alias Promethex.Spec
  alias Promethex.Spec.{Bucket, Metric}
  alias Promethex.Metric.{Counter, Gauge}

  @test_specs [
    %Spec{name: "test.counter", type: :COUNTER},
    %Spec{name: "test.gauge", type: :GAUGE}
  ]

  test "Init promethex" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest1)

    Process.sleep(100)

    assert Promethex.lookup_metric("test.counter") ==
             {:ok, %Metric{buckets: %{}, help: nil, name: "test.counter", type: :COUNTER}}

    assert Promethex.lookup_metric("test.gauge") ==
             {:ok, %Metric{buckets: %{}, help: nil, name: "test.gauge", type: :GAUGE}}

    Process.exit(pid, :normal)
  end

  test "Test gauge" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest2)

    Process.sleep(100)

    Gauge.set("test.gauge", 100)
    Gauge.set("test.gauge", 100, test: 2)

    assert Promethex.lookup_metric("test.gauge") ==
             {:ok,
              %Metric{
                buckets: %{
                  [] => %Bucket{timestamp: nil, value: 100},
                  [test: 2] => %Bucket{timestamp: nil, value: 100}
                },
                help: nil,
                name: "test.gauge",
                type: :GAUGE
              }}

    Gauge.inc("test.gauge", 1)
    Gauge.dec("test.gauge", 2, test: 2)

    assert Promethex.lookup_metric("test.gauge") ==
             {:ok,
              %Metric{
                buckets: %{
                  [] => %Bucket{timestamp: nil, value: 101},
                  [test: 2] => %Bucket{timestamp: nil, value: 98}
                },
                help: nil,
                name: "test.gauge",
                type: :GAUGE
              }}

    Process.exit(pid, :normal)
  end

  test "Test counter" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest3)

    Process.sleep(100)

    Counter.inc("test.counter", 1)
    Counter.inc("test.counter", 2, test: 2)

    assert Promethex.lookup_metric("test.counter") ==
             {:ok,
              %Metric{
                buckets: %{
                  [] => %Bucket{timestamp: nil, value: 1},
                  [test: 2] => %Bucket{timestamp: nil, value: 2}
                },
                help: nil,
                name: "test.counter",
                type: :COUNTER
              }}

    Process.exit(pid, :normal)
  end
end
