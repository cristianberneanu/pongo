defmodule PongoWeb.PlayerView do
  use PongoWeb, :view

  defdelegate parameters(), to: Pongo.Match
end
