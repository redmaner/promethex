defmodule Promethex.Encoder do
  @moduledoc false
  alias Promethex.Spec.{Bucket, Metric}

  def encode(metrics) when is_list(metrics) do
    metrics
    |> Enum.reduce("", fn metric, acc ->
      acc <> encode(metric)
    end)
    |> Kernel.<>("\n")
  end

  def encode(%Metric{buckets: buckets, type: type, name: name, help: help, created: created}) do
    enc_type = type |> to_string() |> String.downcase()
    bucket_name = encode_name(name, type)

    "# TYPE #{name} #{enc_type}\n"
    |> encode_help(name, help)
    |> encode_buckets(bucket_name, buckets)
    |> encode_created(name, created, type)
  end

  defp encode_help(enc_data, _name, help) when help in ["", nil], do: enc_data

  defp encode_help(enc_data, name, help) do
    enc_data <> "# HELP #{name} #{help}\n"
  end

  defp encode_buckets(enc_data, name, buckets) when buckets == %{} do
    enc_data <> "#{name} 0\n"
  end

  defp encode_buckets(enc_data, name, buckets) do
    {no_label, buckets} = Map.pop(buckets, [])

    enc_data =
      if no_label do
        enc_data |> encode_bucket(name, {[], no_label})
      else
        enc_data
      end

    buckets
    |> Enum.reduce(enc_data, &encode_bucket(&2, name, &1))
  end

  defp encode_bucket(enc_data, name, {labels, %Bucket{value: value}}) when labels != [] do
    labels =
      labels
      |> Stream.map(fn {key, name} -> "#{key}=#{name}" end)
      |> Enum.join(",")

    enc_data <> "#{name}{#{labels}} #{value}\n"
  end

  defp encode_bucket(enc_data, name, {_labels, %Bucket{value: value}}) do
    enc_data <> "#{name} #{value}\n"
  end

  defp encode_name(name, type) when type == :COUNTER, do: name <> "_total"
  defp encode_name(name, _type), do: name

  defp encode_created(enc_data, name, created, type)
       when is_integer(created) and type == :COUNTER do
    enc_data <> "#{name}_created #{created}\n"
  end

  defp encode_created(enc_data, _name, _created, _type), do: enc_data
end
