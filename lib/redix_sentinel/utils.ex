defmodule RedixSentinel.Utils do
  @moduledoc false

  def format_error(:tcp_closed) do
    "TCP connection closed"
  end

  def format_error(:closed) do
    "the connection to Redis is closed"
  end

  def format_error(reason) do
    case :inet.format_error(reason) do
      'unknown POSIX error' -> inspect(reason)
      message -> List.to_string(message)
    end
  end

  def format_host(opts) do
    "#{opts[:host]}:#{opts[:port]}"
  end

  def next_backoff(current, backoff_max) do
    next = round(current * 1.5)

    if backoff_max == :infinity do
      next
    else
      min(next, backoff_max)
    end
  end


  @default_opts [
    backoff_initial: 500,
    backoff_max: 30_000
  ]

  @log_default_opts [
    disconnection: :error,
    failed_connection: :error,
    reconnection: :info,
  ]

  @redix_behaviour_opts [:socket_opts, :sync_connect, :backoff_initial, :backoff_max, :log, :exit_on_disconnection]
  @sentinel_behaviour_opts [:backoff_initial, :backoff_max]
  def split_opts(sentinel_opts, redis_connection_opts, redix_opts) do
    {redix_behaviour_opts, connection_opts} = Keyword.split(redix_opts, @redix_behaviour_opts)
    not_supported([:host, :port], redis_connection_opts)
    not_supported([:exit_on_disconnection, :sync_connect], redix_opts)

    {sentinel_behaviour_opts, redix_behaviour_opts} = Keyword.split(redix_behaviour_opts, @sentinel_behaviour_opts)
    sentinel_opts = Keyword.merge(sentinel_opts, @default_opts)
    |> Keyword.merge(sentinel_behaviour_opts)
    |> Keyword.put(:log, Keyword.get(redix_behaviour_opts, :log, @log_default_opts))

    {sentinel_opts, redis_connection_opts, redix_behaviour_opts, connection_opts}
  end

  defp not_supported(keys, opts) do
    for key <- keys do
      if Keyword.get(opts, key) do
        raise ArgumentError, "#{key} option is not supported"
      end
    end
  end
end
