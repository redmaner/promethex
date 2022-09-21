defmodule Promethex do
  use GenServer

  alias Promethex.Spec
  alias Promethex.Spec.{Bucket, Metric}

  @ets_table_name :promethex_registry

  defmodule UndefinedMetric do
    defexception [:message]
  end

  defmodule InvalidMetricAction do
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

  defp init_metric(%Spec{name: name, type: type, help: help}) do
    metric = %Metric{
      type: type,
      name: name,
      help: help,
      buckets: %{}
    }

    true = :ets.insert(@ets_table_name, {name, metric})
  end

  def handle_metric(
        [:promethex_metric_event],
        %{value: value},
        %{type: type, action: action, name: name, labels: labels},
        _config
      ) do
    case lookup_metric(name) do
      {:ok, metric = %Metric{type: metric_type, buckets: buckets}} ->
        if metric_type != type do
          raise InvalidMetricAction
        end

        new_value = update_metric_value(buckets, labels, value, type, action)
        buckets = metric.buckets |> Map.put(labels, new_value)
        new_metric = %Metric{metric | buckets: buckets}

        true = :ets.insert(@ets_table_name, {name, new_metric})

      _else ->
        raise UndefinedMetric
    end
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
        {:ok, metrics}

      _else ->
        :error
    end
  end

  defp update_metric_value(buckets, labels, value, _type, _action)
       when not is_map_key(buckets, labels) do
    %Bucket{value: value}
  end

  defp update_metric_value(buckets, labels, value, type, action) do
    bucket = Map.fetch!(buckets, labels)

    cond do
      type == :GAUGE and action == :set ->
        %Bucket{value: value}

      type == :GAUGE and action == :dec ->
        %Bucket{value: bucket.value - value}

      true ->
        %Bucket{value: bucket.value + value}
    end
  end
end
