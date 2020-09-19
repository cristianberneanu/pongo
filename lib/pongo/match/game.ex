defmodule Pongo.Match.Game do
  alias Pongo.Match.Vec

  @parameters %{
    paddle_length: 100,
    paddle_height: 20,
    ball_radius: 8,
    field_width: 920,
    field_height: 690,
    wall_width: 15
  }

  @paddle_speed 700 / 1_000_000
  @ball_initial_speed 300 / 1_000_000
  @ball_max_speed 700 / 1_000_000
  @ball_acceleration 10 / 1_000_000 / 1_000_000
  @iterations 4
  @direction_y_limit 0.33
  @ball_x_impulse_on_hit 0.33

  @derive Jason.Encoder
  defstruct ball: Vec.new(@parameters.field_width / 2, @parameters.field_height / 2),
            direction: Vec.new(0, 0),
            speed: @ball_initial_speed,
            player1: @parameters.field_width / 2,
            player2: @parameters.field_width / 2,
            last_collision: nil,
            id: nil,
            sound: nil

  def parameters(), do: @parameters

  def new(id), do: %__MODULE__{id: id}

  def start(state) do
    direction = Vec.new(2 * :rand.uniform() - 1, Enum.random([1, -1])) |> Vec.normalize()
    %__MODULE__{state | direction: direction, sound: "start"}
  end

  def invert(state) do
    %__MODULE__{
      state
      | player1: state.player2,
        player2: state.player1,
        ball: Vec.new(state.ball.x, @parameters.field_height - state.ball.y),
        direction: Vec.new(state.direction.x, state.direction.y)
    }
  end

  def advance(state, time_step, player1_speed, player2_speed) do
    state = %{state | sound: nil}
    iteration_step = time_step / @iterations

    state =
      Enum.reduce(1..@iterations, state, fn _i, state ->
        objects = objects(state.player1, player1_speed, state.player2, player2_speed)

        speed = min(state.speed + @ball_acceleration * iteration_step, @ball_max_speed)

        object_index = collide(state.ball, objects)

        state =
          if object_index not in [nil, state.last_collision] do
            direction = objects |> Enum.at(object_index) |> bounce(state.direction)
            %{state | direction: direction, last_collision: object_index, sound: "bounce"}
          else
            state
          end

        ball = state.direction |> Vec.mul(speed * iteration_step) |> Vec.add(state.ball)

        player1 = limit_player(state.player1 + player1_speed * @paddle_speed * iteration_step)
        player2 = limit_player(state.player2 + player2_speed * @paddle_speed * iteration_step)

        %__MODULE__{state | player1: player1, player2: player2, ball: ball, speed: speed}
      end)

    cond do
      state.ball.y < -@parameters.ball_radius ->
        :player2_wins

      state.ball.y > @parameters.field_height + @parameters.ball_radius ->
        :player1_wins

      true ->
        {:ok, state}
    end
  end

  @left_edge 0 + @parameters.wall_width + @parameters.paddle_length / 2
  @right_edge @parameters.field_width - @parameters.wall_width - @parameters.paddle_length / 2

  defp limit_player(position), do: clamp(position, @left_edge, @right_edge)

  defp clamp(value, min, max), do: min(max, max(min, value))

  def hits?(ball, from, to) do
    r = @parameters.ball_radius
    d = Vec.sub(to, from)
    f = Vec.sub(from, ball)

    a = 2 * Vec.dot(d, d)
    b = 2 * Vec.dot(f, d)
    c = Vec.dot(f, f) - r * r

    discriminant = b * b - 2 * a * c

    if discriminant < 0 do
      false
    else
      discriminant = :math.sqrt(discriminant)
      t1 = (-b - discriminant) / a
      t2 = (-b + discriminant) / a

      (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
    end
  end

  @wall_left {
    Vec.new(@parameters.wall_width, 0),
    Vec.new(@parameters.wall_width, @parameters.field_height),
    Vec.new(1, 0),
    Vec.new(0, 0)
  }

  @wall_right {
    Vec.new(@parameters.field_width - @parameters.wall_width, 0),
    Vec.new(@parameters.field_width - @parameters.wall_width, @parameters.field_height),
    Vec.new(-1, 0),
    Vec.new(0, 0)
  }

  defp objects(player1, player1_speed, player2, player2_speed) do
    paddle1 = {
      Vec.new(
        player1 - @parameters.paddle_length / 2,
        @parameters.field_height - @parameters.paddle_height
      ),
      Vec.new(
        player1 + @parameters.paddle_length / 2,
        @parameters.field_height - @parameters.paddle_height
      ),
      Vec.new(0, 1),
      Vec.new(@ball_x_impulse_on_hit * player1_speed, 0)
    }

    paddle2 = {
      Vec.new(player2 - @parameters.paddle_length / 2, @parameters.paddle_height),
      Vec.new(player2 + @parameters.paddle_length / 2, @parameters.paddle_height),
      Vec.new(0, -1),
      Vec.new(@ball_x_impulse_on_hit * player2_speed, 0)
    }

    [@wall_left, @wall_right, paddle1, paddle2]
  end

  defp collide(ball, objects) do
    Enum.find_index(objects, fn {from, to, _normal, _impulse} -> hits?(ball, from, to) end)
  end

  defp limit_direction(%{x: x, y: y}) do
    y = if y >= 0, do: max(y, @direction_y_limit), else: min(y, -@direction_y_limit)
    Vec.new(x, y)
  end

  defp bounce({_from, _to, normal, impulse}, direction) do
    direction |> Vec.reflect(normal) |> Vec.add(impulse) |> limit_direction() |> Vec.normalize()
  end
end
