defmodule Worker do
  use GenServer, restart: :transient

  def start_link(state = %{supervisor_pid: supervisor_pid}, opts \\ [])
      when is_pid(supervisor_pid) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    #
    # After the worker is started, it needs to fetch current state from state Agent.
    #
    {:ok, state, {:continue, :post_init}}
  end

  def handle_continue(:post_init, state) do
    state =
      state
      |> WorkerSupervisor.get_agent_state()

    IO.puts("Worker #{inspect(self())} initialized. Supervisor #{inspect(state.supervisor_pid)}. Initial count #{state.counter}")

    self()
    |> Process.send_after(:tick, state.interval)

    {:noreply, state}
  end

  def handle_info(:tick, state) do
    state =
      state
      |> Map.update!(:counter, &(&1 + 1))

    state
    |> WorkerSupervisor.set_agent_state()

    self()
    |> Process.send_after(:tick, state.interval)

    {:noreply, state}
  end
end
