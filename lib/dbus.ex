defmodule Dbus do
  use Application
  require Logger
  alias Dbus.Redis, as: R

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [worker(Dbus.Redis, [])]
    opts = [strategy: :one_for_one, name: Dbus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def kill()do
    Logger.info("Removing all topics and messages...\n")
    R.q!(["SMEMBERS", "topics"]) |> Enum.map(&unregister(&1))
    R.q(["DEL", "topics"])
    Logger.debug("DONE, Removing all topics and messages.\n")
  end
  def is_topic(topic), do: R.q!(["SISMEMBER","topics",topic]) == "1"
  def topics(), do: R.q!(["SMEMBERS","topics"])
  def register(name) do
    was_added = R.q!(["SADD","topics",name]) == "1"
    if was_added do
      Logger.info("Registered topic #{name}.\n")
    else
      Logger.debug("Topic #{name}, already registered.\n")
    end
  end
  def unregister(name) do
    was_removed = R.q!(["SREM","topics",name]) == "1"
    R.q!(["DEL","topics.#{name}"])

    if was_removed do
      Logger.info("Unregistered topic #{name}, and removed all messages.\n")
    else
      Logger.debug("Topic #{name} does not exist, nothing to unregister.\n")
    end
  end

  def pub(topic,msg) do
    R.q!(["RPUSH", topic_id(topic), msg |> serialize])
    Logger.debug("Sent #{topic}:\n#{msg |> serialize}\n")
  end

  def peek(topic), do: _peek(topic, 0)
  def peek(_topic, 0), do: []
  def peek(topic, :all), do: _peek(topic, 0)
  def peek(topic,num), do: _peek(topic, num)
  def pop(topic), do: pop(topic, :next)
  def pop(topic, :next), do: R.q!(["LPOP",topic_id(topic)]) |> deserialize
  def pop(_topic, 0), do: []
  def pop(topic, -1), do: pop(topic, :all)
  def pop(topic, :all) do
    answer = peek(topic, :all)
    R.q!(["DEL",topic_id(topic)])
    answer
  end
  def pop(topic, num), do: 1..num |> Enum.map(fn(_i) -> pop(topic, :next) end) |> Enum.filter(&(!is_nil(&1)))
  def size(topic), do: R.q!(["LLEN",topic_id(topic)]) |> String.to_integer
  def process(topic, my_fn), do: process(topic, my_fn, :all)
  def process(topic, my_fn, num) do
    pop(topic, num)
    |> Enum.map(&(my_fn.(&1)))
  end
  def sub(topic, my_fn) do
    _sub(topic, my_fn, pop(topic))
    Logger.debug("Subscribing to #{topic}.\n")
  end

  defp serialize(msg), do: :erlang.term_to_binary(msg)
  defp deserialize(:undefined), do: nil
  defp deserialize(msg), do: :erlang.binary_to_term(msg)
  defp deserialize_all(msgs), do: Enum.map(msgs, &deserialize/1)
  defp _peek(topic, num), do: R.q!(["LRANGE",topic_id(topic),0,num - 1]) |> deserialize_all

  defp _sub(topic, my_fn, nil) do
    Logger.debug("Subscriber to #{topic} sleeping 5 seconds awaiting message.\n")
    :timer.sleep(5*1000)
    sub(topic, my_fn)
  end

  defp _sub(topic, my_fn, msg) do
    my_fn.(msg)
    Logger.debug("Received #{topic}:\n#{msg |> serialize}\n")
    sub(topic, my_fn)
  end

  defp topic_id(topic), do: "topics.#{topic}"

end
