defmodule State do
  use Agent

  def start_link(state, options \\ []) do
    Agent.start_link(fn -> state end, options)
  end
end
