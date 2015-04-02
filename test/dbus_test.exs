defmodule DbusTest do
  use ExUnit.Case

  def xxx_fn(args) do
    Dbus.Redis.q(["RPUSH","test",args[:var]])
  end

  setup do
    Dbus.kill
    Dbus.Redis.q(["del","test"])
    { :ok, [] }
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


end
