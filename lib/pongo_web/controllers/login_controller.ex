defmodule PongoWeb.LoginController do
  use PongoWeb, :controller

  def index(conn, _params) do
    render(conn)
  end

  def login(conn, params) do
    if params["name"] in [nil, ""] do
      conn
      |> put_flash(:error, "Player name must be non-empty!")
      |> render(:index)
    else
      conn
      |> put_session(:name, params["name"])
      |> put_session(:tag, params["tag"] || "")
      |> redirect(to: "/play")
    end
  end
end
