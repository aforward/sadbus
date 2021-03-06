defmodule Dbus.Redis do
  use Supervisor

  @defaults [host: "localhost",
             port: 6379,
             pool_size: 5,
             max_overflow: 0]

  @doc """
  Start the shared connection pool connecting to Redis
  """
  def start_link() do
    opts = Application.get_env(:redis, __MODULE__)
    Supervisor.start_link(__MODULE__, [opts])
  end

  @doc false
  def init([opts]) do
    pool_opts = [{:name, {:local, :redis_pool}},
                 {:worker_module, :eredis},
                 {:size, n(opts, :pool_size)},
                 {:max_overflow, n(opts, :max_overflow)}]
    eredis_opts = [{:host, String.to_char_list(l(opts, :host))},
                   {:port, n(opts, :port)}]
    children = [:poolboy.child_spec(:redis_pool, pool_opts, eredis_opts)]
    supervise(children, strategy: :one_for_one)
  end

  @doc """
  Run a redis query with the expected timeout
  from the provided `queues`.

  E.g. q(["GET","mytitle"]) => {:ok, "I am awesome"}
  """
  def q(args, timeout \\ 5*1000) do
    :poolboy.transaction(:redis_pool, fn(worker) -> :eredis.q(worker, args, timeout) end)
  end

  @doc """
  Run the redis query, and assume the answer will be :ok and simply
  return the data

  E.g. q(["GET","mytitle"]) => "I am awesome"
  """
  def q!(args, timeout \\ 5*1000) do
    {:ok, data} = q(args, timeout)
    data
  end

  defp l(opts, key), do: opts[key] || @defaults[key]
  defp n(opts, key), do: n(l(opts, key))
  defp n(str) when is_binary(str), do: String.to_integer(str)
  defp n(num) when is_integer(num), do: num

end