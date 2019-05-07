defmodule WorkerSupervisor do
  use Supervisor

  defp get_child_pid(supervisor_pid, child_type)
       when is_pid(supervisor_pid) and child_type in [State, Worker] do
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

  defp kill_child(supervisor_pid, child_type) when is_pid(supervisor_pid) and child_type in [State, Worker]  do
    supervisor_pid
    |> get_child_pid(child_type)
    |> Process.exit(:kill)
  end

  def kill_worker(supervisor_pid), do: supervisor_pid  |> kill_child(Worker)
  def kill_state(supervisor_pid), do: supervisor_pid  |> kill_child(State)

  def get_interval(supervisor_pid) when is_pid(supervisor_pid) do
    supervisor_pid
    |> get_state_pid()
    |> Agent.get(& &1.interval)
  end

  def get_counter(supervisor_pid) when is_pid(supervisor_pid) do
    supervisor_pid
    |> get_state_pid()
    |> Agent.get(& &1.counter)
  end

  def start_link(initial_state \\ %{interval: 1_000, counter: 0}) do
    Supervisor.start_link(__MODULE__, initial_state)
  end

  @impl true
  def init(initial_state = %{interval: _, counter: _}) do
    children = [
      {State, initial_state},
      {Worker, %{supervisor_pid: self()}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
