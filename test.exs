require Logger
defmodule Test do
  def loop(x, i \\ 0) do
    try do
      x.(i)
    catch
      :exit, {:timeout, _} ->
        :ok
      :exit, reason ->
        Logger.error "[exit]=================> #{inspect(reason)}"
        :ok
      :error, %Redix.Error{message: message} ->
        Logger.error "[error]=================> #{message}"
        :ok
    end
    Process.sleep(100)
    loop(x, i+1)
  end
end

sentinels = [
  [host: "sentinel_3", port: 30000],
  [host: "sentinel_2", port: 20000],
  [host: "sentinel_1", port: 10000]
]

spawn_link(fn ->
  {:ok, conn} = RedixSentinel.start_link([group: "demo", sentinels: sentinels, role: "slave", verify_role: 10_000])
  Test.loop(fn i ->
    case RedixSentinel.command(conn, ["GET", "#{i}"]) do
      {:ok, _} ->
        if Integer.mod(i, 100) == 0 do
          Logger.debug "GET #{i}"
        end
      {:error, _error} -> :ok
    end
  end)
end)

spawn_link(fn ->
  {:ok, conn} = RedixSentinel.start_link([group: "demo", sentinels: sentinels, role: "master", verify_role: 10_000])
  Test.loop(fn i ->
    case RedixSentinel.command(conn, ["SET", "#{i}", "#{i}"]) do
      {:ok, _} ->
        if Integer.mod(i, 100) == 0 do
          Logger.debug "SET #{i}"
        end
      {:error, _error} -> :ok
    end
  end)
end)

Process.sleep(:infinity)
