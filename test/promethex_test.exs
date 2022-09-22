defmodule PromethexTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Promethex.Spec
  alias Promethex.Spec.{Metric, MetricPoint}
  alias Promethex.Metric.{Counter, Gauge}

  @test_specs [
    %Spec{name: "test.counter", type: :COUNTER},
    %Spec{name: "test.gauge", type: :GAUGE}
  ]

  test "Init promethex" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest1)

    Process.sleep(100)

    {:ok, metric} = Promethex.lookup_metric("test.counter")

    assert metric ==
             %Metric{
               metric_points: %{},
               help: nil,
               name: "test.counter",
               type: :COUNTER,
               created: metric.created
             }

    {:ok, metric} = Promethex.lookup_metric("test.gauge")

    assert metric ==
             %Metric{
               metric_points: %{},
               help: nil,
               name: "test.gauge",
               type: :GAUGE,
               created: metric.created
             }

    Process.exit(pid, :normal)
  end

  test "Test gauge" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest2)

    Process.sleep(100)

    Gauge.set("test.gauge", 100)
    Gauge.set("test.gauge", 100, test: 2)

    {:ok, metric} = Promethex.lookup_metric("test.gauge")

    assert metric ==
             %Metric{
               metric_points: %{
                 [] => %MetricPoint{timestamp: nil, value: 100},
                 [test: 2] => %MetricPoint{timestamp: nil, value: 100}
               },
               help: nil,
               name: "test.gauge",
               type: :GAUGE,
               created: metric.created
             }

    Gauge.inc("test.gauge", 1)
    Gauge.dec("test.gauge", 2, test: 2)

    {:ok, metric} = Promethex.lookup_metric("test.gauge")

    assert metric ==
             %Metric{
               metric_points: %{
                 [] => %MetricPoint{timestamp: nil, value: 101},
                 [test: 2] => %MetricPoint{timestamp: nil, value: 98}
               },
               help: nil,
               name: "test.gauge",
               type: :GAUGE,
               created: metric.created
             }

    Process.exit(pid, :normal)
  end

  test "Test counter" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest3)

    Process.sleep(100)

    Counter.inc("test.counter", 1)
    Counter.inc("test.counter", 2, test: 2)

    {:ok, metric} = Promethex.lookup_metric("test.counter")

    assert metric ==
             %Metric{
               metric_points: %{
                 [] => %MetricPoint{timestamp: nil, value: 1},
                 [test: 2] => %MetricPoint{timestamp: nil, value: 2}
               },
               help: nil,
               name: "test.counter",
               type: :COUNTER,
               created: metric.created
             }

    Process.exit(pid, :normal)
  end

  test "Test metric for undefined metric" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest4)

    Process.sleep(100)

    assert capture_log(fn ->
             Counter.inc("test.counter2", 1)
           end) =~ "Undefined prometheus metric: metric test.counter2 is not defined"

    Process.exit(pid, :normal)
  end

  test "Test invalid action for metric" do
    {:ok, pid} = Promethex.start_link(@test_specs, :promethextest4)

    Process.sleep(100)

    assert capture_log(fn ->
             Gauge.set("test.counter", 1)
           end) =~
             "Invalid action for prometheus metric: set not allowed for metric test.counter of type GAUGE"

    Process.exit(pid, :normal)
  end
end
