defmodule Dbus do
  use Application
  require Logger
  alias Dbus.Redis, as: R

  @recent_index -100

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [worker(Dbus.Redis, [])]
    opts = [strategy: :one_for_one, name: Dbus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def kill()do
    Logger.info("Removing all topics and messages...")
    R.q!(["SMEMBERS", "topics"]) |> Enum.map(&unregister(&1))
    R.q(["DEL", "topics"])
    Logger.debug("DONE, Removing all topics and messages.")
  end
  def is_topic(topic), do: R.q!(["SISMEMBER", "topics", topic]) == "1"
  def topics(), do: R.q!(["SMEMBERS", "topics"])
  def register(name) do
    was_added = R.q!(["SADD", "topics", name]) == "1"
    if was_added do
      Logger.info("Registered topic #{name}.")
    else
      Logger.debug("Topic #{name}, already registered.")
    end
  end
  def unregister(topic) do
    was_removed = R.q!(["SREM", "topics", topic]) == "1"
    if was_removed do
      R.q!(["DEL",
            topic_id(topic),
            total_id(topic),
            num_processed_id(topic),
            num_failed_id(topic),
            recent_processed_id(topic),
            recent_failed_id(topic)])
      Logger.info("Unregistered topic #{topic}, and removed all messages.")
    else
      Logger.debug("Topic #{topic} does not exist, nothing to unregister.")
    end
  end

  def pub(topic, msg) do
    R.q!(["RPUSH", topic_id(topic), msg |> serialize])
    R.q!(["INCR", total_id(topic)])
    Logger.debug("Sent #{topic}: #{msg |> inspect}")
  end

  def peek(topic), do: _peek(topic, 0)
  def peek(_topic, 0), do: []
  def peek(topic, :all), do: _peek(topic, 0)
  def peek(topic, num), do: _peek(topic, num)
  def pop(topic), do: pop(topic, :next)
  def pop(topic, :next), do: R.q!(["LPOP", topic_id(topic)]) |> deserialize
  def pop(_topic, 0), do: []
  def pop(topic, -1), do: pop(topic, :all)
  def pop(topic, :all) do
    answer = peek(topic, :all)
    R.q!(["DEL", topic_id(topic)])
    answer
  end
  def pop(topic, num), do: 1..num |> Enum.map(fn(_i) -> pop(topic, :next) end) |> Enum.filter(&(!is_nil(&1)))
  def size(topic), do: R.q!(["LLEN", topic_id(topic)]) |> to_i
  def num_total(topic), do: R.q!(["GET", total_id(topic)]) |> to_i
  def num_processed(topic), do: R.q!(["GET", num_processed_id(topic)]) |> to_i
  def num_failed(topic), do: R.q!(["GET", num_failed_id(topic)]) |> to_i
  def processed(topic), do: R.q!(["LRANGE", recent_processed_id(topic), 0, -1]) |> deserialize_all
  def failed(topic), do: R.q!(["LRANGE", recent_failed_id(topic), 0, -1]) |> deserialize_all
  def process(topic, my_fn), do: process(topic, my_fn, :all)
  def process(topic, my_fn, num), do: pop(topic, num) |> Enum.map(&(_process(topic, my_fn, &1)))

  def sub(topic, my_fn) do
    _sub(topic, my_fn, pop(topic))
    Logger.debug("Subscribing to #{topic}.")
  end

  defp serialize(msg), do: :erlang.term_to_binary(msg)
  defp deserialize(:undefined), do: nil
  defp deserialize(msg), do: :erlang.binary_to_term(msg)
  defp deserialize_all(msgs), do: Enum.map(msgs, &deserialize/1)
  defp _peek(topic, num), do: R.q!(["LRANGE", topic_id(topic), 0, num - 1]) |> deserialize_all

  defp _sub(topic, my_fn, nil) do
    Logger.debug("Subscriber to #{topic} sleeping 5 seconds awaiting message.")
    :timer.sleep(5*1000)
    sub(topic, my_fn)
  end

  defp _sub(topic, my_fn, msg) do
    my_fn.(msg)
    Logger.debug("Received #{topic}: #{msg |> inspect}")
    sub(topic, my_fn)
  end

  defp _process(topic, my_fn, msg) do
    try do
      my_fn.(msg)
      add_processed(topic, msg)
      Logger.debug("Processd message (#{topic}): #{msg |> inspect}")
    catch t ->
      add_failed(topic, msg)
      Logger.error("Failed (catch) to process (#{topic}): #{msg |> inspect} due to #{t}")
    rescue e ->
      add_failed(topic, msg)
      Logger.error("Failed (rescue) to process (#{topic}): #{msg |> inspect} due to #{e |> inspect}")
    end
  end

  defp add_processed(topic, msg), do: add_observed(msg, num_processed_id(topic), recent_processed_id(topic))
  defp add_failed(topic, msg), do: add_observed(msg, num_failed_id(topic), recent_failed_id(topic))
  defp add_observed(msg, num_id, recent_id) do
    R.q!(["INCR", num_id])
    R.q!(["RPUSH", recent_id, msg |> serialize])
    R.q!(["LTRIM", recent_id, @recent_index, -1])
  end

  defp topic_id(topic), do: "topics.#{topic}"
  defp total_id(topic), do: "topics.#{topic}.num-total"
  defp num_processed_id(topic), do: "topics.#{topic}.num-processed"
  defp num_failed_id(topic), do: "topics.#{topic}.num-failed"
  defp recent_processed_id(topic), do: "topics.#{topic}.recent-processed"
  defp recent_failed_id(topic), do: "topics.#{topic}.recent-failed"

  defp to_i(""), do: 0
  defp to_i(:undefined), do: 0
  defp to_i(num) when is_integer(num), do: num
  defp to_i(num) when is_binary(num), do: num |> String.to_integer

end
