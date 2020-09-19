defmodule Pongo.Match do
  @moduledoc false

  use GenServer

  alias Pongo.Match.Game

  @update_interval 66
  @start_pause 800
  @end_pause 400

  def parameters() do
    Map.merge(
      %{
        update_interval: @update_interval
      },
      Game.parameters()
    )
  end

  def start(pid1, name1, pid2, name2) do
    GenServer.start(__MODULE__, [pid1, name1, pid2, name2])
  end

  @impl true
  def init([pid1, name1, pid2, name2]) do
    Process.monitor(pid1)
    Process.monitor(pid2)

    state = %{
      player1: pid1,
      player2: pid2,
      game: Game.new(0),
      previous_update_time: :erlang.timestamp(),
      player1_keys: %{left: 0, right: 0},
      player2_keys: %{left: 0, right: 0},
      player1_score: 0,
      player2_score: 0
    }

    send_msg(pid1, {:connect, self(), name2, state.game})
    send_msg(pid2, {:connect, self(), name1, state.game})

    Process.send_after(self(), {:start, :erlang.timestamp(), @start_pause}, @update_interval)

    {:ok, state}
  end

  @impl true
  def handle_info(:new, state) do
    state = %{state | game: Game.new(state.player1_score + state.player2_score)}
    Process.send_after(self(), {:start, :erlang.timestamp(), @start_pause}, @update_interval)
    {:noreply, send_update(state)}
  end

  def handle_info({:start, previous_update_time, countdown}, state) do
    now = :erlang.timestamp()
    time_step = :timer.now_diff(now, previous_update_time)

    player1_speed = state.player1_keys.right - state.player1_keys.left
    player2_speed = state.player2_keys.right - state.player2_keys.left

    {:ok, game} = Game.advance(state.game, time_step, player1_speed, player2_speed)

    countdown = countdown - time_step / 1000

    state =
      if countdown < 0 do
        Process.send_after(self(), {:play, now}, @update_interval)
        %{state | game: Game.start(state.game)}
      else
        Process.send_after(self(), {:start, now, countdown}, @update_interval)
        %{state | game: game}
      end

    {:noreply, send_update(state)}
  end

  def handle_info({:play, previous_update_time}, state) do
    now = :erlang.timestamp()
    time_step = :timer.now_diff(now, previous_update_time)

    player1_speed = state.player1_keys.right - state.player1_keys.left
    player2_speed = state.player2_keys.right - state.player2_keys.left

    state =
      case Game.advance(state.game, time_step, player1_speed, player2_speed) do
        {:ok, game} ->
          Process.send_after(self(), {:play, now}, @update_interval)
          %{state | game: game}

        game_result ->
          Process.send_after(self(), :new, @end_pause)
          state |> update_score(game_result) |> send_scores()
      end

    {:noreply, send_update(state)}
  end

  def handle_info({:DOWN, _ref, :process, pid1, _reason}, %{player1: pid1, player2: pid2}) do
    send_msg(pid2, :disconnect)
    {:stop, :normal, nil}
  end

  def handle_info({:DOWN, _ref, :process, pid2, _reason}, %{player1: pid1, player2: pid2}) do
    send_msg(pid1, :disconnect)
    {:stop, :normal, nil}
  end

  @impl true
  def handle_cast({player1, key, mode}, %{player1: player1, player1_keys: keys} = state) do
    state = %{state | player1_keys: Map.put(keys, key, mode)}
    {:noreply, state}
  end

  def handle_cast({player2, key, mode}, %{player2: player2, player2_keys: keys} = state) do
    state = %{state | player2_keys: Map.put(keys, key, mode)}
    {:noreply, state}
  end

  defp send_update(state) do
    send_msg(state.player1, {:update, state.game})
    send_msg(state.player2, {:update, Game.invert(state.game)})
    state
  end

  defp send_msg(pid, msg), do: GenServer.cast(pid, msg)

  defp update_score(state, :player1_wins), do: %{state | player1_score: state.player1_score + 1}
  defp update_score(state, :player2_wins), do: %{state | player2_score: state.player2_score + 1}

  defp send_scores(state) do
    send_msg(state.player1, {:score, state.player1_score, state.player2_score})
    send_msg(state.player2, {:score, state.player2_score, state.player1_score})
    state
  end
end
