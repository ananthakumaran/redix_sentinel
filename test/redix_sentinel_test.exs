defmodule RedixSentinelTest do
  use ExUnit.Case, async: false
  doctest RedixSentinel

  @sentinel_config [
    group: "demo",
    role: "master",
    sentinels: [
      [host: "sentinel_3", port: 30000],
      [host: "sentinel_2", port: 20000],
      [host: "sentinel_1", port: 10000]
    ]
  ]

  test "dies when the linked node dies" do
    current = self()
    spawn(fn ->
      {ok, pid} = RedixSentinel.start_link(@sentinel_config, [], [name: :sentinel])
      {:ok, "PONG"} = RedixSentinel.command(pid, ["PING"])
      send(current, {:pid, pid})
      raise "error"
    end)
    receive do
      {:pid, pid} ->
        Process.sleep(100)
        assert Process.alive?(pid) === false
    after
      1000 -> flunk("Failed to receive PONG")
    end
  end

  test "restarts redix connection if it dies normally" do
    {ok, pid} = RedixSentinel.start_link(@sentinel_config, [], [name: :sentinel])
    {:ok, "PONG"} = RedixSentinel.command(pid, ["PING"])
    {:ok, node} = Connection.call(pid, :node)
    :ok = Redix.stop(node)
    Process.sleep(500)
    {:ok, "PONG"} = RedixSentinel.command(pid, ["PING"])
    :ok = RedixSentinel.stop(pid)
  end

  test "restarts redix connection if it dies abnormally" do
    {ok, pid} = RedixSentinel.start_link(@sentinel_config, [], [name: :sentinel])
    {:ok, "PONG"} = RedixSentinel.command(pid, ["PING"])
    {:ok, node} = Connection.call(pid, :node)
    Process.exit(node, :kill)
    Process.sleep(500)
    {:ok, "PONG"} = RedixSentinel.command(pid, ["PING"])
    :ok = RedixSentinel.stop(pid)
  end

  test "stops redix connection" do
    {ok, pid} = RedixSentinel.start_link(@sentinel_config, [], [name: :sentinel])
    {:ok, "PONG"} = RedixSentinel.command(pid, ["PING"])
    {:ok, node} = Connection.call(pid, :node)
    Process.alive?(node) == true
    :ok = RedixSentinel.stop(pid)
    Process.alive?(node) == false
    Process.alive?(pid) == false
  end

  test "catch noproc errors" do
    current = self()
    {ok, pid} = RedixSentinel.start_link(@sentinel_config, [], [name: :sentinel])
    {:ok, node} = Connection.call(pid, :node)
    :sys.suspend(pid)
    spawn_link(fn ->
      {:error, :closed} = RedixSentinel.command(pid, ["PING"])
      send(current, :ok)
    end)
    Process.sleep(500)
    Process.exit(node, :kill)
    :sys.resume(pid)
    receive do
      :ok -> :ok
    after
      1000 -> flunk("Failed to receive response for PING")
    end
    :ok = RedixSentinel.stop(pid)
  end
end
