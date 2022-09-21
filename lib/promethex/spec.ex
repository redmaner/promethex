defmodule Promethex.Spec do
  @moduledoc """
  Provides specification to define a new Prometheus metric
  """

  @type metric_type :: :COUNTER | :GAUGE | :HISTOGRAM

  @type t :: %__MODULE__{
          type: metric_type(),
          name: atom(),
          help: binary()
        }

  @enforce_keys [:type, :name]
  defstruct [:type, :name, :help]

  defmodule Bucket do
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
            buckets: %{Keyword.t() => Bucket.t()}
          }

    @enforce_keys [:type, :name, :buckets]
    defstruct [:type, :name, :help, :buckets]
  end
end
