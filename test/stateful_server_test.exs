defmodule StatefulServerTest do
  use ExUnit.Case
  doctest StatefulServer

  test "greets the world" do
    assert StatefulServer.hello() == :world
  end
end
