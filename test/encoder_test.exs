defmodule EncoderTest do
  use ExUnit.Case

  alias Promethex.Encoder
  alias Promethex.Spec.{Bucket, Metric}

  test "encode counter with no data" do
    metric = %Metric{
      type: :COUNTER,
      name: "test_counter",
      buckets: %{},
      created: 123_456_789
    }

    assert Encoder.encode(metric) ==
             "# TYPE test_counter counter\ntest_counter_total 0\ntest_counter_created 123456789\n"
  end

  test "encode counter with default bucket" do
    metric = %Metric{
      type: :COUNTER,
      name: "test_counter",
      buckets: %{[] => %Bucket{value: 25}}
    }

    assert Encoder.encode(metric) == "# TYPE test_counter counter\ntest_counter_total 25\n"
  end

  test "encode counter with multiple buckets" do
    metric = %Metric{
      type: :COUNTER,
      name: "test_counter",
      buckets: %{
        [] => %Bucket{value: 25},
        [test: 1, labels: 2] => %Bucket{value: 50},
        [test: 2] => %Bucket{value: 75}
      }
    }

    assert Encoder.encode(metric) ==
             "# TYPE test_counter counter\ntest_counter_total 25\ntest_counter_total{test=1,labels=2} 50\ntest_counter_total{test=2} 75\n"
  end

  test "encode gauge with default bucket" do
    metric = %Metric{
      type: :GAUGE,
      name: "test_gauge",
      buckets: %{[] => %Bucket{value: 25}}
    }

    assert Encoder.encode(metric) == "# TYPE test_gauge gauge\ntest_gauge 25\n"
  end
end
