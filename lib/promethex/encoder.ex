defmodule Promethex.Encoder do
  @moduledoc false
  alias Promethex.Spec.{Metric, MetricPoint}

  def encode(metrics) when is_list(metrics) do
    metrics
    |> Enum.reduce("", fn metric, acc ->
      acc <> encode(metric)
    end)
    |> Kernel.<>("\n")
  end

  def encode(%Metric{
        metric_points: metric_points,
        type: type,
        name: name,
        help: help,
        sum: sum,
        count: count,
        created: created
      }) do
    enc_type = type |> to_string() |> String.downcase()
    metric_point_name = encode_name(name, type)

    enc_data =
      "# TYPE #{name} #{enc_type}\n"
      |> encode_help(name, help)
      |> encode_metric_points(metric_point_name, metric_points)

    case type do
      :COUNTER ->
        enc_data
        |> encode_extra(name, "created", created)

      :HISTOGRAM ->
        enc_data
        |> encode_extra(name, "sum", sum)
        |> encode_extra(name, "count", count)
        |> encode_extra(name, "created", created)

      :GAUGE ->
        enc_data
    end
  end

  defp encode_help(enc_data, _name, help) when help in ["", nil], do: enc_data

  defp encode_help(enc_data, name, help) do
    enc_data <> "# HELP #{name} #{help}\n"
  end

  defp encode_metric_points(enc_data, name, metric_points) when metric_points == %{} do
    enc_data <> "#{name} 0\n"
  end

  defp encode_metric_points(enc_data, name, metric_points) do
    {no_label, metric_points} = Map.pop(metric_points, [])

    enc_data =
      if no_label do
        enc_data |> encode_metric_point(name, {[], no_label})
      else
        enc_data
      end

    metric_points
    |> Enum.reduce(enc_data, &encode_metric_point(&2, name, &1))
  end

  defp encode_metric_point(enc_data, name, {labels, %MetricPoint{value: value}})
       when labels != [] do
    labels =
      labels
      |> Stream.map(fn {key, name} -> ~s(#{key}="#{name}") end)
      |> Enum.join(",")

    enc_data <> "#{name}{#{labels}} #{value}\n"
  end

  defp encode_metric_point(enc_data, name, {_labels, %MetricPoint{value: value}}) do
    enc_data <> "#{name} #{value}\n"
  end

  defp encode_name(name, :COUNTER), do: name <> "_total"
  defp encode_name(name, :HISTOGRAM), do: name <> "_bucket"
  defp encode_name(name, _type), do: name

  defp encode_extra(enc_data, _name, _suffix, value) when is_nil(value) do
    enc_data
  end

  defp encode_extra(enc_data, name, suffix, value) do
    enc_data <> "#{name}_#{suffix} #{value}\n"
  end
end
