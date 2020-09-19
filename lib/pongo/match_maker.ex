defmodule Pongo.MatchMaker do
  @moduledoc false

  alias Pongo.Match

  use GenServer

  def register(tag, name) do
    GenServer.call(__MODULE__, {:register, tag, name}, :infinity)
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(nil) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, tag, name}, {from, _}, state) do
    state =
      case Map.pop(state, tag, nil) do
        {nil, state} ->
          ref = Process.monitor(from)
          state |> Map.put(tag, %{pid: from, name: name}) |> Map.put(from, %{tag: tag, ref: ref})

        {%{pid: opponent_pid, name: opponent_name}, state} ->
          {%{tag: ^tag, ref: ref}, state} = Map.pop(state, opponent_pid)
          Process.demonitor(ref, [:flush])
          {:ok, _} = Match.start(from, name, opponent_pid, opponent_name)
          state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {%{tag: tag, ref: ref}, state} = Map.pop(state, pid)

    Process.demonitor(ref, [:flush])

    {%{pid: ^pid}, state} = Map.pop(state, tag)

    {:noreply, state}
  end
end
