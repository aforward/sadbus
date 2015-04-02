defmodule DbusTest do
  use ExUnit.Case

  setup do
    Dbus.kill
    { :ok, [] }
  end

  test "topics - default" do
    assert Dbus.topics() == []
  end

  test "topics - add some" do
    Dbus.add_topic("xx")
    Dbus.add_topic("yy")
    assert (Dbus.topics() |> Enum.sort) == ["xx", "yy"]
  end

end
