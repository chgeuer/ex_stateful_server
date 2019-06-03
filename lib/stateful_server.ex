defmodule StatefulServer do
  defmodule Demo do
    alias StatefulServer.WorkerSupervisor, as: WorkerSupervisor

    def demo do
      once_per_second = Demo.start(200)
      ten_per_second = Demo.start(220)
      hundret_per_second = Demo.start(250)

      IO.puts("Launced processes")
      Process.sleep(1_500)
      [once_per_second, ten_per_second, hundret_per_second] |> show() |> IO.inspect()

      Process.sleep(1_500)
      [once_per_second, ten_per_second, hundret_per_second] |> show() |> IO.inspect()

      IO.puts("Killing processes")

      once_per_second |> WorkerSupervisor.kill_worker()
      ten_per_second |> WorkerSupervisor.kill_worker()
      hundret_per_second |> WorkerSupervisor.kill_worker()

      Process.sleep(1_500)
      once_per_second |> WorkerSupervisor.kill_state()
      ten_per_second |> WorkerSupervisor.kill_state()
      hundret_per_second |> WorkerSupervisor.kill_state()

      Process.sleep(1_500)
      once_per_second |> WorkerSupervisor.kill_worker()
      ten_per_second |> WorkerSupervisor.kill_worker()
      hundret_per_second |> WorkerSupervisor.kill_worker()

      Process.sleep(1_500)
      [once_per_second, ten_per_second, hundret_per_second] |> show() |> IO.inspect()

      [once_per_second, ten_per_second, hundret_per_second]
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

  defmodule WorkerSupervisor do
    alias StatefulServer.Worker, as: Worker

    use Supervisor

    @start_link_defaults %{interval: 1_000, counter: 0}

    defp find_child(pid, child_type)
         when is_pid(pid) and child_type in [Agent, Worker],
         do:
           pid
           |> Supervisor.which_children()
           |> Enum.find(fn {type, _, :worker, _} -> type == child_type end)

    defp get_child_pid(pid, child_type)
         when is_pid(pid) and child_type in [Agent, Worker] do
      with {^child_type, child_pid, :worker, _} <- find_child(pid, child_type) do
        case child_pid |> Process.alive?() do
          true -> child_pid
          false -> get_child_pid(pid, child_type)
        end
      end
    end

    defp kill_child(pid, child_type)
         when is_pid(pid) and child_type in [Agent, Worker] do
      pid
      |> get_child_pid(child_type)
      |> Process.exit(:kill)
    end

    def get_state_pid(pid), do: pid |> get_child_pid(Agent)
    def get_worker_pid(pid), do: pid |> get_child_pid(Worker)
    def kill_state(pid), do: pid |> kill_child(Agent)
    def kill_worker(pid), do: pid |> kill_child(Worker)

    def get(pid, function) when is_pid(pid),
      do:
        pid
        |> get_state_pid()
        |> Agent.get(function)

    def get_interval(pid), do: pid |> get(& &1.interval)

    def get_counter(pid), do: pid |> get(& &1.counter)

    def get_agent_state(%{state_pid: pid}),
      do:
        pid
        |> Agent.get(& &1)

    def get_agent_state(%{supervisor_pid: pid}),
      do:
        pid
        |> StatefulServer.WorkerSupervisor.get_state_pid()
        |> Agent.get(& &1)

    def set_agent_state(worker_state = %{state_pid: pid}),
      do:
        pid
        |> Agent.update(fn _ -> worker_state end)

    def start_link(state \\ @start_link_defaults),
      do: Supervisor.start_link(__MODULE__, state)

    @impl true
    def init(initial_state = %{interval: _, counter: _}) do
      pid = self()
      agent_state = initial_state |> Map.put(:supervisor_pid, pid)

      children = [
        # {Agent, fn -> agent_state end},
        # {Worker, %{supervisor_pid: pid}, restart: :permanent}
        worker(Agent, [fn -> agent_state end]),
        worker(Worker, [%{supervisor_pid: pid}], restart: :permanent)
      ]

      Supervisor.init(children, strategy: :rest_for_one, max_restarts: 10)
    end
  end

  defmodule Worker do
    use GenServer, restart: :transient

    def start_link(state = %{supervisor_pid: pid}, opts \\ [])
        when is_pid(pid) do
      GenServer.start_link(__MODULE__, state, opts)
    end

    def init(state) do
      #
      # After the worker is started, it needs to fetch current state from state Agent.
      #
      {:ok, state, {:continue, :post_init}}
    end

    def handle_continue(:post_init, %{supervisor_pid: supervisor_pid} = state) do
      state_pid =
        supervisor_pid
        |> WorkerSupervisor.get_state_pid()

      state =
        state
        |> WorkerSupervisor.get_agent_state()
        |> Map.put(:state_pid, state_pid)

      # IO.puts(
      #   "Worker #{inspect(self())} initialized. Supervisor #{inspect(state.supervisor_pid)}. Agent #{
      #     inspect(state.supervisor_pid |> WorkerSupervisor.get_state_pid())
      #   } Initial count #{state.counter}"
      # )

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
end
