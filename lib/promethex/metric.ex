defmodule Promethex.Metric do
  def dispatch(name, type, action, value, labels) do
    :telemetry.execute([:promethex_metric_event], %{value: value}, %{
      type: type,
      action: action,
      labels: labels,
      name: name
    })
  end

  defmodule Counter do
    def inc(name, value \\ 1, labels \\ []) do
      Promethex.Metric.dispatch(name, :COUNTER, :inc, value, labels)
    end
  end

  defmodule Gauge do
    def inc(name, value \\ 1, labels \\ []) do
      Promethex.Metric.dispatch(name, :GAUGE, :inc, value, labels)
    end

    def dec(name, value \\ 1, labels \\ []) do
      Promethex.Metric.dispatch(name, :GAUGE, :dec, value, labels)
    end

    def set(name, value \\ 1, labels \\ []) do
      Promethex.Metric.dispatch(name, :GAUGE, :set, value, labels)
    end
  end

  defmodule Histogram do
    def inc(name, value \\ 1) do
      Promethex.Metric.dispatch(name, :HISTOGRAM, :inc, value, [])
    end
  end
end
