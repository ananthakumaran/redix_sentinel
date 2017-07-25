defmodule RedixSentinel do
  require Logger
  alias RedixSentinel.Utils
  use Connection

  defmodule State do
    @moduledoc false

    defstruct sentinel_opts: [],
              redis_connection_opts: [],
              redix_behaviour_opts: [],
              node: nil,
              node_info: nil,
              backoff_current: nil
  end

  @spec start_link(Keyword.t, Keyword.t, Keyword.t) :: GenServer.on_start
  def start_link(sentinel_opts, redis_connection_options \\ [], redix_opts \\ []) do
    {sentinel_opts, redis_connection_opts, redix_behaviour_opts, connection_opts} = Utils.split_opts(sentinel_opts, redis_connection_options, redix_opts)
    Connection.start_link(__MODULE__, {sentinel_opts, redis_connection_opts, redix_behaviour_opts}, connection_opts)
  end

  @spec close(GenServer.server) :: :ok
  def close(conn) do
    Connection.stop(conn)
  end

  def pipeline(conn, commands, opts \\ []) do
    with {:ok, node} <- get_node(conn) do
      Redix.pipeline(node, commands, opts)
    end
  end

  def pipeline!(conn, commands, opts \\ []) do
    with {:ok, node} <- get_node(conn) do
      Redix.pipeline!(node, commands, opts)
    end
  end

  def command(conn, command, opts \\ []) do
    with {:ok, node} <- get_node(conn) do
      Redix.command(node, command, opts)
    end
  end

  def command!(conn, command, opts \\ []) do
    with {:ok, node} <- get_node(conn) do
      Redix.command!(node, command, opts)
    end
  end

  defp get_node(conn) do
    Connection.call(conn, :node)
  end

  def init({sentinel_opts, redis_connection_opts, redix_behaviour_opts}) do
    Process.flag(:trap_exit, true)
    {:connect, :init, %State{redix_behaviour_opts: redix_behaviour_opts, redis_connection_opts: redis_connection_opts, sentinel_opts: sentinel_opts}}
  end

  def connect(info, %State{sentinel_opts: sentinel_opts, redis_connection_opts: redis_connection_opts} = s) do
    case find_and_connect(s) do
      {:ok, s} ->
        if info == :backoff || info == :reconnect do
          log(s, :reconnection, ["Reconnected to (", Utils.format_host(s.node_info), ")"])
        end
        s = %{s | backoff_current: nil}
        {:ok, s}
      {:error, reason} ->
        backoff = get_backoff(s)
        log(s, :failed_connection, ["Failed to connect to ", to_string(Keyword.fetch!(sentinel_opts, :role)), " node ", Utils.format_error(reason), ". Sleeping for ", to_string(backoff), "ms."])
        {:backoff, backoff, %{s | backoff_current: backoff}}
      {:stop, reason} -> {:stop, reason, s}
    end
  end

  def disconnect({:error, reason}, %State{node_info: node_info} = s) do
    log(s, :disconnection, ["Disconnected from (", Utils.format_host(node_info), "): ", Utils.format_error(reason)])
    cleanup(s)
    {:connect, :reconnect, %{s | node: nil, backoff_current: nil, node_info: nil}}
  end

  def handle_call(:node, _from, %State{node: nil} = s) do
    {:reply, {:error, :closed}, s}
  end

  def handle_call(:node, _from, %State{node: node} = s) do
    {:reply, {:ok, node}, s}
  end

  def handle_info({:EXIT, _, :noproc}, s) do
    error = {:error, :closed}
    {:disconnect, error, s}
  end

  def handle_info({:EXIT, node, reason}, %State{node: node} = s) do
    error = {:error, reason}
    {:disconnect, error, s}
  end

  def handle_info(msg, state) do
    _ = Logger.warn(["Unknown message: ", inspect(msg)])
    {:noreply, state}
  end

  def terminate(_reason, state) do
    cleanup(state)
  end

  ## Private ##

  defp get_backoff(s) do
    if !s.backoff_current do
      s.sentinel_opts[:backoff_initial]
    else
      Utils.next_backoff(s.backoff_current, s.sentinel_opts[:backoff_max])
    end
  end

  defp cleanup(%State{node: node}) do
    if node do
      try do
        Redix.stop(node)
      catch
        :exit, _ -> :ok
      end
    end
    :ok
  end

  defp find_and_connect(%State{sentinel_opts: sentinel_opts} = s) do
    try_sentinel(s, [], Keyword.fetch!(sentinel_opts, :sentinels))
  end

  defp try_sentinel(%State{sentinel_opts: sentinel_opts} = s, tried, []) do
    {:error, "Failed to connect via any sentinel"}
  end

  defp try_sentinel(%State{sentinel_opts: sentinel_opts} = s, tried, [sentinel_connection_opts | rest]) do
    role = Keyword.fetch!(sentinel_opts, :role)
    current = self()
    {pid, reference} = spawn_monitor(fn ->
      Logger.debug "Trying sentinel #{inspect(sentinel_connection_opts)}"
      {:ok, sentinel_conn} = Redix.start_link(sentinel_connection_opts, Keyword.merge(s.redix_behaviour_opts, [exit_on_disconnection: true, sync_connect: true]))
      node_info = get_node_info(sentinel_conn, Keyword.fetch!(sentinel_opts, :group), role)

      Logger.debug "Got #{role} address #{inspect(node_info)}"
      {:ok, conn} = Redix.start_link(Keyword.merge(s.redis_connection_opts, node_info), Keyword.merge(s.redix_behaviour_opts, [exit_on_disconnection: true]))

      Logger.debug "Verifying role"
      [^role | _] = Redix.command!(conn, ["ROLE"])

      Redix.stop(sentinel_conn)

      s = %{s | node: conn, node_info: node_info}
      send(current, {:ok, s})
    end)
    receive do
      {:DOWN, ^reference, :process, ^pid, reason} ->
        try_sentinel(s, [sentinel_connection_opts | tried], rest)
      {:ok, s} ->
        Process.demonitor(reference, [:flush])
        Process.link(s.node)
        {:ok, s}
    end
  end

  defp log(state, action, message) do
    level =
      state.sentinel_opts
      |> Keyword.fetch!(:log)
      |> Keyword.fetch!(action)
    Logger.log(level, message)
  end

  def get_node_info(conn, group, "master") do
    [host, port] = Redix.command!(conn, ["SENTINEL", "get-master-addr-by-name", group])
    [host: host, port: String.to_integer(port)]
  end

  def get_node_info(conn, group, "slave") do
    Redix.command!(conn, ["SENTINEL", "slaves", group])
    |> Enum.random
    |> Enum.chunk(2)
    |> Enum.filter_map(fn [key, value] ->
      Enum.member?(["ip", "port"], key)
    end, fn [key, value] ->
      case key do
        "ip" -> {:host, value}
        "port" -> {:port, String.to_integer(value)}
      end
    end)
  end
end
