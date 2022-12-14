defmodule Promethex.Spec do
  @moduledoc """
  Provides specification to define a new Prometheus metric
  """

  @type metric_type :: :COUNTER | :GAUGE | :HISTOGRAM

  @type t :: %__MODULE__{
          type: metric_type(),
          name: atom(),
          help: binary(),
          buckets: [integer()] | nil
        }

  @enforce_keys [:type, :name]
  defstruct [:type, :name, :help, :buckets]

  defmodule MetricPoint do
    @moduledoc false

    @typedoc false
    @type t :: %__MODULE__{
            timestamp: number(),
            value: number()
          }

    @enforce_keys [:value]
    defstruct [:timestamp, :value]
  end

  defmodule Metric do
    @moduledoc false

    @typedoc false
    @type t :: %__MODULE__{
            type: Promethex.Spec.metric_type(),
            name: atom(),
            help: binary(),
            metric_points: %{Keyword.t() => MetricPoint.t()},
            buckets: [integer()] | nil,
            count: integer(),
            sum: integer(),
            created: integer()
          }

    @enforce_keys [:type, :name, :metric_points]
    defstruct [:type, :name, :help, :metric_points, :buckets, :sum, :count, :created]
  end
end
