defmodule Demo do
  def demo do
    {:ok, sup1} = WorkerSupervisor.start_link()
    {:ok, sup2} = WorkerSupervisor.start_link(%{interval: 200, counter: -10})

    [sup1, sup2]
  end

  def start(interval) when is_integer(interval) do
    with {:ok, pid} <- WorkerSupervisor.start_link(%{interval: interval, counter: 0}) do
      pid
    end
  end

  def show(supervisors) do
    supervisors
    |> Enum.map(fn sup ->
      sup
      |> WorkerSupervisor.get_counter()
      |> Integer.to_string()
    end)
  end
end
