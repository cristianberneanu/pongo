defmodule Pongo.Match.Vec do
  def new(x, y), do: %{x: x, y: y}

  def add(v1, v2), do: new(v1.x + v2.x, v1.y + v2.y)
  def sub(v1, v2), do: new(v1.x - v2.x, v1.y - v2.y)
  def dot(v1, v2), do: v1.x * v2.x + v1.y * v2.y
  def mul(v, s), do: new(v.x * s, v.y * s)

  def normalize(v) do
    magn = :math.sqrt(v.x * v.x + v.y * v.y)
    new(v.x / magn, v.y / magn)
  end

  def reflect(v, n), do: sub(v, mul(n, 2 * dot(v, n)))
end
