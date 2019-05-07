defmodule WorkerSupervisor do
  alias State, as: S
  alias Worker, as: W

  use Supervisor

  @start_link_defaults %{interval: 1_000, counter: 0}

  defp find_child(supervisor_pid, child_type)
       when is_pid(supervisor_pid) and child_type in [S, W],
       do:
         supervisor_pid
         |> Supervisor.which_children()
         |> Enum.find(fn {type, _, :worker, _} -> type == child_type end)

  defp get_child_pid(supervisor_pid, child_type)
       when is_pid(supervisor_pid) and child_type in [S, W] do
    with {^child_type, pid, :worker, _} <- find_child(supervisor_pid, child_type) do
      pid
    end
  end

  defp kill_child(supervisor_pid, child_type)
       when is_pid(supervisor_pid) and child_type in [S, W] do
    supervisor_pid
    |> get_child_pid(child_type)
    |> Process.exit(:kill)
  end

  def get_state_pid(supervisor_pid), do: supervisor_pid |> get_child_pid(S)
  def get_worker_pid(supervisor_pid), do: supervisor_pid |> get_child_pid(W)
  def kill_state(supervisor_pid), do: supervisor_pid |> kill_child(S)
  def kill_worker(supervisor_pid), do: supervisor_pid |> kill_child(W)

  def get_interval(supervisor_pid) when is_pid(supervisor_pid),
    do:
      supervisor_pid
      |> get_state_pid()
      |> Agent.get(& &1.interval)

  def get_counter(supervisor_pid) when is_pid(supervisor_pid),
    do:
      supervisor_pid
      |> get_state_pid()
      |> Agent.get(& &1.counter)

  def get_agent_state(%{supervisor_pid: supervisor_pid}),
    do:
      supervisor_pid
      |> get_state_pid()
      |> Agent.get(& &1)

  def set_agent_state(worker_state = %{supervisor_pid: supervisor_pid}),
    do:
      supervisor_pid
      |> get_state_pid()
      |> Agent.update(fn _ -> worker_state end)

  def start_link(state \\ @start_link_defaults),
    do: Supervisor.start_link(__MODULE__, state)

  @impl true
  def init(initial_state = %{interval: _, counter: _}) do
    supervisor_pid = self()

    children = [
      {S, initial_state |> Map.put(:supervisor_pid, supervisor_pid)},
      {W, %{supervisor_pid: supervisor_pid}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
