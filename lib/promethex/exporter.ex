defmodule Promethex.Exporter do
  @behaviour Plug

  defp defaults do
    [
      path: "/metrics",
      method: "GET"
    ]
  end

  def init(opts) do
    defaults()
    |> Keyword.merge(opts)
  end

  def call(conn = %Plug.Conn{request_path: req_path, method: req_method},
        path: conf_path,
        method: conf_method
      )
      when req_path == conf_path and req_method == conf_method do
    case Promethex.get_all() do
      {:ok, metrics} ->
        body = Promethex.Encoder.encode(metrics)

        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, body)
        |> Plug.Conn.halt()

      :error ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "Internal errror")
        |> Plug.Conn.halt()
    end
  end

  def call(conn, _opts) do
    conn
  end
end
