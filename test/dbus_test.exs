defmodule DbusTest do
  use ExUnit.Case

  def xxx_fn(args) do
    Dbus.Redis.q(["RPUSH","test",args[:var]])
  end

  def answer_to_life(msg) do
    if msg == 42 || msg == "forty-two" do
      # do nothing
    else
      throw(msg)
    end
  end

  setup do
    Logger.disable(self())
    Dbus.kill
    Dbus.Redis.q(["del","test"])
    { :ok, [] }
  end

  test "is_topic" do
    assert Dbus.is_topic(nil) == false
    assert Dbus.is_topic("a") == false
    assert Dbus.is_topic(:a) == false

    Dbus.register("b")
    assert Dbus.is_topic("a") == false
    assert Dbus.is_topic(:a) == false
    assert Dbus.is_topic("b") == true
    assert Dbus.is_topic(:b) == true
  end

  test "topics - default" do
    assert Dbus.topics() == []
  end

  test "topics - add some" do
    Dbus.register("xx")
    Dbus.register("yy")
    assert (Dbus.topics() |> Enum.sort) == ["xx", "yy"]
  end

  test "pub" do
    Dbus.register("xxx")
    Dbus.pub("xxx", [var: "1"])
    assert Dbus.peek("xxx") == [[var: "1"]]
    Dbus.pub("xxx", [var: "2"])
    assert Dbus.peek("xxx") == [[var: "1"], [var: "2"]]
  end

  test "pop" do
    Dbus.register("xxx")
    Dbus.pub("xxx", [var: "1"])
    Dbus.pub("xxx", [var: "2"])
    assert Dbus.pop("xxx") == [var: "1"]
    assert Dbus.peek("xxx") == [[var: "2"]]
  end

  test "pop - next" do
    Dbus.register("xxx")
    Dbus.pub("xxx", [var: "1"])
    Dbus.pub("xxx", [var: "2"])
    assert Dbus.pop("xxx", :next) == [var: "1"]
    assert Dbus.peek("xxx") == [[var: "2"]]
  end

  test "pop - all" do
    Dbus.register("xxx")
    Dbus.pub("xxx", [var: "1"])
    Dbus.pub("xxx", [var: "2"])
    Dbus.pub("xxx", [var: "3"])
    Dbus.pub("xxx", [var: "4"])
    Dbus.pub("xxx", [var: "5"])
    assert Dbus.size("xxx") == 5
    assert Dbus.pop("xxx", 0) == []
    assert Dbus.size("xxx") == 5
    assert Dbus.pop("xxx", 2) == [[var: "1"], [var: "2"]]
    assert Dbus.size("xxx") == 3
    assert Dbus.pop("xxx", :all) == [[var: "3"], [var: "4"], [var: "5"]]

    Dbus.pub("xxx", [var: "a"])
    Dbus.pub("xxx", [var: "b"])
    assert Dbus.pop("xxx", -1) == [[var: "a"], [var: "b"]]
    assert Dbus.size("xxx") == 0

    Dbus.pub("xxx", [var: "x"])
    assert Dbus.pop("xxx", 99) == [[var: "x"]]
  end

  test "peek - all" do
    Dbus.register("xxx")
    Dbus.pub("xxx", [var: "1"])
    Dbus.pub("xxx", [var: "2"])
    Dbus.pub("xxx", [var: "3"])
    assert Dbus.peek("xxx") == [[var: "1"], [var: "2"], [var: "3"]]
    assert Dbus.peek("xxx", :all) == [[var: "1"], [var: "2"], [var: "3"]]
    assert Dbus.peek("xxx",0) == []
    assert Dbus.peek("xxx",99) == [[var: "1"], [var: "2"], [var: "3"]]
    assert Dbus.peek("xxx",2) == [[var: "1"], [var: "2"]]
  end

  test "size" do
    Dbus.register("xxx")
    assert Dbus.size("xxx") == 0
    Dbus.pub("xxx", [var: "1"])
    Dbus.pub("xxx", [var: "2"])
    assert Dbus.size("xxx") == 2
    Dbus.pop("xxx")
    assert Dbus.size("xxx") == 1
  end

  test "num_total -- running total" do
    Dbus.register("xxx")
    assert Dbus.num_total("xxx") == 0
    Dbus.pub("xxx", [var: "1"])
    Dbus.pub("xxx", [var: "2"])
    assert Dbus.num_total("xxx") == 2
    Dbus.pop("xxx")
    assert Dbus.num_total("xxx") == 2
    Dbus.pub("xxx", [var: "2"])
    assert Dbus.num_total("xxx") == 3
  end

  test "num_processed -- running num_total" do
    Dbus.register("xxx")
    Dbus.pub("xxx", 42)
    Dbus.pub("xxx", 42)
    assert Dbus.num_processed("xxx") == 0
    assert Dbus.num_failed("xxx") == 0
    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.num_processed("xxx") == 1
    assert Dbus.num_failed("xxx") == 0
    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.num_processed("xxx") == 2
    assert Dbus.num_failed("xxx") == 0
  end

  test "num_failed -- running num_total" do
    Dbus.register("xxx")
    Dbus.pub("xxx", 41)
    Dbus.pub("xxx", 40)
    assert Dbus.num_processed("xxx") == 0
    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.num_processed("xxx") == 0
    assert Dbus.num_failed("xxx") == 1
    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.num_processed("xxx") == 0
    assert Dbus.num_failed("xxx") == 2
  end

  test "process - all" do
    Dbus.register("xxx")
    Dbus.pub("xxx", [var: "one"])
    Dbus.pub("xxx", [var: "deux"])
    assert Dbus.size("xxx") == 2
    Dbus.process("xxx",&xxx_fn/1)
    assert Dbus.size("xxx") == 0
    assert Dbus.Redis.q!(["LRANGE", "test", 0, -1]) == ["one","deux"]
  end

  test "process - one" do
    Dbus.register("xxx")
    Dbus.pub("xxx", [var: "one"])
    Dbus.pub("xxx", [var: "deux"])
    assert Dbus.size("xxx") == 2
    Dbus.process("xxx", &xxx_fn/1, 1)
    assert Dbus.size("xxx") == 1
    assert Dbus.Redis.q!(["LRANGE", "test", 0, -1]) == ["one"]
  end

  test "processed" do
    Dbus.register("xxx")
    Dbus.pub("xxx", 42)
    Dbus.pub("xxx", "forty-two")
    assert Dbus.processed("xxx") == []
    assert Dbus.failed("xxx") == []

    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.processed("xxx") == [42]
    assert Dbus.failed("xxx") == []

    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.processed("xxx") == [42, "forty-two"]
    assert Dbus.failed("xxx") == []
  end

  test "failed" do
    Dbus.register("xxx")
    Dbus.pub("xxx", 41)
    Dbus.pub("xxx", 40)

    assert Dbus.processed("xxx") == []
    assert Dbus.failed("xxx") == []

    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.processed("xxx") == []
    assert Dbus.failed("xxx") == [41]

    Dbus.process("xxx", &answer_to_life/1, 1)
    assert Dbus.processed("xxx") == []
    assert Dbus.failed("xxx") == [41, 40]
  end
end
