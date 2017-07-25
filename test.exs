defmodule Test do
  def loop(x, i \\ 0) do
    try do
      x.(i)
    catch
      :exit, _ -> :ok
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
  {:ok, conn} = RedixSentinel.start_link([group: "demo", sentinels: sentinels, role: "slave"])
  Test.loop(fn i ->
    case RedixSentinel.command(conn, ["GET", "#{i}"]) do
      {:ok, _} ->
        if Integer.mod(i, 100) do
          IO.puts "#{i}"
        end
      {:error, error} -> IO.inspect(error)
    end
  end)
end)

spawn_link(fn ->
  {:ok, conn} = RedixSentinel.start_link([group: "demo", sentinels: sentinels, role: "master"])
  Test.loop(fn i ->
    case RedixSentinel.command(conn, ["SET", "#{i}", "#{i}"]) do
      {:ok, _} ->
        if Integer.mod(i, 100) do
          IO.puts "#{i}"
        end
      {:error, error} -> IO.inspect(error)
    end
  end)
end)

Process.sleep(:infinity)
