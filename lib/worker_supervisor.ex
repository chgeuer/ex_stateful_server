defmodule WorkerSupervisor do
  use Supervisor

  defp get_child_pid(supervisor_pid, child_type)
       when is_pid(supervisor_pid) and is_atom(child_type) do
    supervisor_pid
    |> Supervisor.which_children()
    |> Enum.filter(fn {type, _pid, :worker, _} ->
      case type do
        ^child_type -> true
        _ -> false
      end
    end)
    |> hd()
    |> elem(1)
  end

  def get_state_pid(supervisor_pid), do: supervisor_pid |> get_child_pid(State)
  def get_worker_pid(supervisor_pid), do: supervisor_pid |> get_child_pid(Worker)

  def get_interval(supervisor_pid) when is_pid(supervisor_pid) do
    supervisor_pid
    |> get_state_pid()
    |> Agent.get(& &1.interval)
  end

  def get_counter({:supervisor, supervisor_pid}) when is_pid(supervisor_pid) do
    state_pid =
      supervisor_pid
      |> get_state_pid()

    get_counter({:state, state_pid})
  end

  def get_counter({:state, state_pid}) when is_pid(state_pid) do
    state_pid
    |> Agent.get(& &1.counter)
  end

  def set_counter(state_pid, counter) when is_pid(state_pid) and is_integer(counter) do
    state_pid
    |> Agent.update(fn state -> state |> Map.put(:counter, counter) end)
  end

  def do_work(supervisor_pid) when is_pid(supervisor_pid) do
    supervisor_pid
    |> get_worker_pid()
    |> Worker.get_state_state()
  end

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil)
  end

  @impl true
  def init(_) do
    children = [
      {State, %{interval: 1, counter: 0}},
      {Worker, %{supervisor_pid: self()}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
