defmodule Dbus do
  use Application

  alias Dbus.Redis, as: R

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(Dbus.Redis, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dbus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def kill()do
    R.q!(["SMEMBERS", "topics"]) |> Enum.map(&unregister(&1))
    R.q(["DEL", "topics"])
  end
  def topics(), do: R.q!(["SMEMBERS","topics"])
  def register(name), do: R.q!(["SADD","topics",name])
  def unregister(name) do
    R.q!(["SREM","topics",name])
    R.q!(["DEL","topics.#{name}"])
  end
  def pub(topic,msg), do: R.q!(["RPUSH", "topics.#{topic}", msg |> serialize])
  def peek(topic), do: _peek(topic, 0)
  def peek(_topic, 0), do: []
  def peek(topic, :all), do: _peek(topic, 0)
  def peek(topic,num), do: _peek(topic, num)
  def pop(topic), do: pop(topic, :next)
  def pop(topic, :next), do: R.q!(["LPOP","topics.#{topic}"]) |> deserialize
  def pop(_topic, 0), do: []
  def pop(topic, -1), do: pop(topic, :all)
  def pop(topic, :all) do
    answer = peek(topic, :all)
    R.q!(["DEL","topics.#{topic}"])
    answer
  end
  def pop(topic, num), do: 1..num |> Enum.map(fn(_i) -> pop(topic, :next) end) |> Enum.filter(&(!is_nil(&1)))
  def size(topic), do: R.q!(["LLEN","topics.#{topic}"]) |> String.to_integer
  def process(topic, my_fn), do: process(topic, my_fn, :all)
  def process(topic, my_fn, num) do
    pop(topic, num)
    |> Enum.map(&(my_fn.(&1)))
  end


  defp serialize(msg), do: :erlang.term_to_binary(msg)
  defp deserialize(:undefined), do: nil
  defp deserialize(msg), do: :erlang.binary_to_term(msg)
  defp deserialize_all(msgs), do: Enum.map(msgs, &deserialize/1)
  defp _peek(topic, num), do: R.q!(["LRANGE","topics.#{topic}",0,num - 1]) |> deserialize_all

end
