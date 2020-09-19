defmodule PongoWeb.Player do
  use PongoWeb, :live_view

  alias Pongo.MatchMaker

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: MatchMaker.register(session["tag"], session["name"])
    {:ok, assign(socket, name: session["name"])}
  end

  @impl true
  def handle_event(_, %{"repeat" => true}, socket), do: {:noreply, socket}

  def handle_event("key_down", %{"key" => "ArrowLeft"}, socket),
    do: key_event(:left, 1, socket)

  def handle_event("key_up", %{"key" => "ArrowLeft"}, socket),
    do: key_event(:left, 0, socket)

  def handle_event("key_down", %{"key" => "ArrowRight"}, socket),
    do: key_event(:right, 1, socket)

  def handle_event("key_up", %{"key" => "ArrowRight"}, socket),
    do: key_event(:right, 0, socket)

  def handle_event(_, _, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    if(assigns[:match], do: "match.html", else: "lobby.html")
    |> PongoWeb.PlayerView.render(assigns)
  end

  def handle_cast({:connect, match, opponent_name, game}, socket) do
    {:noreply,
     assign(socket,
       match: match,
       opponent_name: opponent_name,
       game: game,
       score: 0,
       opponent_score: 0
     )}
  end

  def handle_cast({:update, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end

  def handle_cast({:score, score, opponent_score}, socket) do
    {:noreply, assign(socket, score: score, opponent_score: opponent_score)}
  end

  def handle_cast(:disconnect, socket) do
    {:noreply, put_flash(socket, :error, "Opponent disconnected!")}
  end

  defp key_event(key, mode, socket) do
    GenServer.cast(socket.assigns.match, {self(), key, mode})
    {:noreply, socket}
  end
end
