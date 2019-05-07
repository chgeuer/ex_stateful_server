defmodule Worker do
  use GenServer

  def start_link(worker_state = %{supervisor_pid: supervisor_pid}, opts \\ [])
      when is_pid(supervisor_pid) do
    GenServer.start_link(__MODULE__, worker_state, opts)
  end

  def init(worker_state) do
    {:ok, worker_state, {:continue, :post_init}}
  end

  def handle_continue(:post_init, worker_state = %{supervisor_pid: supervisor_pid}) do
    updated_worker_state =
      worker_state
      |> get_agent_state()
      |> Map.put(:supervisor_pid, supervisor_pid)

    self()
    |> Process.send_after(:tick, updated_worker_state.interval)

    {:noreply, updated_worker_state}
  end

  defp get_agent_state(_worker_state = %{supervisor_pid: supervisor_pid}) do
    supervisor_pid
    |> WorkerSupervisor.get_state_pid()
    |> Agent.get(& &1)
  end

  defp set_agent_state(worker_state = %{supervisor_pid: supervisor_pid}) do
    supervisor_pid
    |> WorkerSupervisor.get_state_pid()
    |> Agent.update(fn _ -> worker_state end)
  end

  def handle_info(:tick, state = %{ interval: interval }) do
    updated_state =
      state
      |> Map.update!(:counter, &(&1 + 1))

    updated_state
    |> set_agent_state()

    self()
    |> Process.send_after(:tick, interval)

    {:noreply, updated_state}
  end
end
