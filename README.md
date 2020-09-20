# Pong Online

Online Pong game created using Elixir and Phoenix LiveView.
Demo at: [`pongo.gigalixirapp.com`](https://pongo.gigalixirapp.com)

## How does it work?

* Each `Player` process registers itself with the `MatchMaker` process during `mount`.
* The `MatchMaker` creates a `Match` process with references to 2 `Player` processes.
* The `Match` process receives any input from the players and advances the `Game` state 15 times per second.
* After each update, the `Game` state is sent to each player (the state is inverted for the top player, so both have the same view of the board).
* The state is rendered client-side in a canvas. The client is always a step behind the server and interpolates between the previous state and the current one.

## Dev instructions

To start your Phoenix server:

  * Setup the project with `mix setup`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

