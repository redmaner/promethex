defmodule Promethex do
  require Logger
  use GenServer

  alias Promethex.Spec
  alias Promethex.Spec.{Metric, MetricPoint}

  @ets_table_name :promethex_registry

  defmodule InvalidMetricAction do
    defexception [:message]
  end

  defmodule InvalidMetric do
    defexception [:message]
  end

  @spec start_link(specs :: [Spec.t()], name :: atom()) :: GenServer.on_start()
  def start_link(specs, name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, specs, name: name)
  end

  def init(specs) do
    :ets.new(@ets_table_name, [:set, :public, :named_table])

    :telemetry.attach(
      "promethex-metric-handler",
      [:promethex_metric_event],
      &Promethex.handle_metric/4,
      nil
    )

    {:ok, %{}, {:continue, {:init_specs, specs}}}
  end

  def handle_continue({:init_specs, specs}, state) do
    specs
    |> Enum.each(&init_metric/1)

    {:noreply, state}
  end

  defp init_metric(%Spec{type: :HISTOGRAM, buckets: buckets})
       when buckets == [] or is_nil(buckets) do
    raise InvalidMetric
  end

  defp init_metric(%Spec{type: :HISTOGRAM, name: name, help: help, buckets: buckets}) do
    buckets = sort_buckets(buckets)

    metric = %Metric{
      type: :HISTOGRAM,
      name: name,
      help: help,
      metric_points: %{},
      buckets: buckets,
      count: 0,
      sum: 0,
      created: System.os_time(:second)
    }

    true = :ets.insert(@ets_table_name, {name, metric})
  end

  defp init_metric(%Spec{name: name, type: type, help: help}) do
    metric = %Metric{
      type: type,
      name: name,
      help: help,
      metric_points: %{},
      created: System.os_time(:second)
    }

    true = :ets.insert(@ets_table_name, {name, metric})
  end

  defp sort_buckets(buckets) do
    buckets = ["+Inf" | buckets]

    buckets
    |> Stream.uniq()
    |> Enum.sort(&bucket_sorter/2)
  end

  defp bucket_sorter(value, compare) when is_number(value) and is_number(compare) do
    value <= compare
  end

  defp bucket_sorter("+Inf", _compare) do
    false
  end

  @doc false
  def lookup_metric(name) do
    case :ets.lookup(@ets_table_name, name) do
      result when result == [] -> {:error, :not_found}
      [{^name, metric}] -> {:ok, metric}
    end
  end

  def get_all do
    case :ets.tab2list(@ets_table_name) do
      metrics when metrics != [] ->
        metrics = metrics |> Enum.map(fn {_key, metric} -> metric end)

        {:ok, metrics}

      _else ->
        :error
    end
  end

  def handle_metric(
        [:promethex_metric_event],
        %{value: value},
        %{type: type, action: action, name: name, labels: labels},
        _config
      ) do
    case lookup_metric(name) do
      {:ok, metric = %Metric{type: metric_type, count: count, sum: sum}} ->
        if metric_type != type do
          raise InvalidMetricAction
        end

        {labels, metric_point} = get_metric_point(metric, type, labels, value)
        new_value = update_metric_point_value(metric_point, value, type, action)
        metric_points = metric.metric_points |> Map.put(labels, new_value)

        new_metric =
          if type == :HISTOGRAM do
            %Metric{metric | metric_points: metric_points, count: count + 1, sum: sum + 1}
          else
            %Metric{metric | metric_points: metric_points}
          end

        true = :ets.insert(@ets_table_name, {name, new_metric})

      _else ->
        Logger.warn("Undefined prometheus metric: metric #{name} is not defined")
    end
  rescue
    InvalidMetricAction ->
      Logger.warn(
        "Invalid action for prometheus metric: #{action} not allowed for metric #{name} of type #{type}"
      )
  end

  defp get_metric_point(
         metric = %Metric{buckets: buckets},
         :HISTOGRAM,
         _labels,
         value
       ) do
    labels = select_histogram_bucket(buckets, value)

    get_metric_point(metric, :SELECTED, labels, 1)
  end

  defp get_metric_point(%Metric{metric_points: metric_points}, _type, labels, _value)
       when not is_map_key(metric_points, labels) do
    {labels, %MetricPoint{value: 0}}
  end

  defp get_metric_point(%Metric{metric_points: metric_points}, _type, labels, _value) do
    {labels, Map.fetch!(metric_points, labels)}
  end

  defp select_histogram_bucket(buckets, value) do
    buckets
    |> Enum.reduce_while(false, &in_bucket_range(&1, &2, value))
    |> wrap_bucket()
  end

  defp in_bucket_range("+Inf", _acc, _value) do
    {:halt, [fe: "+Inf"]}
  end

  defp in_bucket_range(bucket_value, _acc, value) do
    if value <= bucket_value do
      {:halt, [fe: bucket_value]}
    else
      {:cont, false}
    end
  end

  defp wrap_bucket(false), do: [fe: "+Inf"]
  defp wrap_bucket(labels), do: labels

  defp update_metric_point_value(metric_point, value, type, action) do
    cond do
      type == :GAUGE and action == :set ->
        %MetricPoint{value: value}

      type == :GAUGE and action == :dec ->
        %MetricPoint{value: metric_point.value - value}

      type == :HISTOGRAM ->
        %MetricPoint{value: metric_point.value + 1}

      true ->
        %MetricPoint{value: metric_point.value + value}
    end
  end
end
