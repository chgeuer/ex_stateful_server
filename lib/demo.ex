defmodule Demo do
  def demo do
    { :ok, sup1 } = WorkerSupervisor.start_link(:nil)
    { :ok, sup2 } = WorkerSupervisor.start_link(:nil)

    [ sup1, sup2 ]
  end

  def show(supervisors) do
    supervisors
    |> Enum.map(fn (sup) -> 
      { :supervisor, sup }
      |> WorkerSupervisor.get_counter()
      |> Integer.to_string()
    end)
  end
end
