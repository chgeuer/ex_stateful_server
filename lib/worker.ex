defmodule Worker do
  use GenServer

  def get_state_state(worker_pid) when is_pid(worker_pid) do
    worker_pid |> GenServer.call(:get_state_state)
  end

  def start_link(%{supervisor_pid: supervisor_pid}, opts \\ []) when is_pid(supervisor_pid) do
    GenServer.start_link(__MODULE__, %{supervisor_pid: supervisor_pid}, opts)
  end

  def init(state = %{supervisor_pid: supervisor_pid}) when is_pid(supervisor_pid) do
    {:ok, state, {:continue, :post_init}}
  end

  def handle_continue(:post_init, state = %{supervisor_pid: supervisor_pid}) do
    state_pid = WorkerSupervisor.get_state_pid(supervisor_pid)

    local_counter = WorkerSupervisor.get_counter({:state, state_pid})

    updated_state =
      state
      |> Map.put(:state_pid, state_pid)
      |> Map.put(:local_counter, local_counter)

    self()
    |> Process.send_after(:tick, 1_000)

    {:noreply, updated_state}
  end

  def handle_info(:tick, state = %{state_pid: state_pid, local_counter: local_counter}) do
    new_local_counter = local_counter + 1

    state_pid
    |> WorkerSupervisor.set_counter(new_local_counter)

    updated_state =
      state
      |> Map.put(:local_counter, new_local_counter)

    self()
      |> Process.send_after(:tick, 1_000)

    {:noreply, updated_state}
  end

  def handle_call(:get_state_state, _, state = %{state_pid: state_pid}) do
    reply = state_pid |> :sys.get_state()

    {:reply, reply, state}
  end
end
