defmodule DBHandler do
  @moduledoc """
  ## Example: create a record
      record = %MarcoPolo.Document{class: "Report", fields: %{"origin_id" => "123", "reference" => "abc", "version" => 1}}
      MarcoPolo.create_record(conn, 12, record)

  ## Example: select a record
      query = "SELECT * FROM Report WHERE origin_id = 123"
      {:ok, [report]} = MarcoPolo.command(conn, query)
  """

  @doc """
  Opens an new Connection to OrientDB.
  ## Examples
      iex> DBHandler.Connection.open host: \"localhost\", port: 5672, virtual_host: \"/\", username: \"guest\", password: \"guest\"
      {:ok, %DBHandler.Connection{}}
      iex> DBHandler.Connection.open \"orientdb://guest:guest@localhost\"
      {:ok, %DBHandler.Connection{}}
  """
  def start_link(options \\ [])

  def start_link(options) when is_list(options) do
    {:ok, conn} = MarcoPolo.start_link(
      connection: {:db, "mydatabase", "document"},
      user: "root",
      password: "0r13ntDB",
      host: "boot2dockerip",
      port: 2424
    )
  end
end
