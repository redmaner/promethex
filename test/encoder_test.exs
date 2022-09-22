defmodule EncoderTest do
  use ExUnit.Case

  alias Promethex.Encoder
  alias Promethex.Spec.{Metric, MetricPoint}

  test "encode counter with no data" do
    metric = %Metric{
      type: :COUNTER,
      name: "test_counter",
      metric_points: %{},
      created: 123_456_789
    }

    assert Encoder.encode(metric) ==
             "# TYPE test_counter counter\ntest_counter_total 0\ntest_counter_created 123456789\n"
  end

  test "encode counter with default metric point" do
    metric = %Metric{
      type: :COUNTER,
      name: "test_counter",
      metric_points: %{[] => %MetricPoint{value: 25}}
    }

    assert Encoder.encode(metric) == "# TYPE test_counter counter\ntest_counter_total 25\n"
  end

  test "encode counter with multiple metric points" do
    metric = %Metric{
      type: :COUNTER,
      name: "test_counter",
      metric_points: %{
        [] => %MetricPoint{value: 25},
        [test: 1, labels: 2] => %MetricPoint{value: 50},
        [test: 2] => %MetricPoint{value: 75}
      }
    }

    assert Encoder.encode(metric) ==
             "# TYPE test_counter counter\ntest_counter_total 25\ntest_counter_total{test=\"1\",labels=\"2\"} 50\ntest_counter_total{test=\"2\"} 75\n"
  end

  test "encode gauge with default metric point" do
    metric = %Metric{
      type: :GAUGE,
      name: "test_gauge",
      metric_points: %{[] => %MetricPoint{value: 25}}
    }

    assert Encoder.encode(metric) == "# TYPE test_gauge gauge\ntest_gauge 25\n"
  end

  test "encode histogram" do
    metric = %Metric{
      metric_points: %{
        [fe: 5] => %Promethex.Spec.MetricPoint{timestamp: nil, value: 4},
        [fe: "+Inf"] => %Promethex.Spec.MetricPoint{timestamp: nil, value: 5},
        [fe: 10] => %Promethex.Spec.MetricPoint{timestamp: nil, value: 5},
        [fe: 1] => %Promethex.Spec.MetricPoint{timestamp: nil, value: 2}
      },
      help: nil,
      buckets: [1, 5, 10, "+Inf"],
      name: "test.histogram",
      type: :HISTOGRAM,
      count: 16,
      sum: 16,
      created: 123_456_789
    }

    assert Encoder.encode(metric) ==
             "# TYPE test.histogram histogram\ntest.histogram_bucket{fe=\"1\"} 2\ntest.histogram_bucket{fe=\"5\"} 4\ntest.histogram_bucket{fe=\"10\"} 5\ntest.histogram_bucket{fe=\"+Inf\"} 5\ntest.histogram_sum 16\ntest.histogram_count 16\ntest.histogram_created 123456789\n"
  end
end
