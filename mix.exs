defmodule RedixSentinel.Mixfile do
  use Mix.Project

  @version "0.4.0"

  def project do
    [app: :redix_sentinel,
     version: @version,
     elixir: "~> 1.2",
     description: "Redix with sentinel support",
     package: package(),
     docs: docs(),
     dialyzer: [
       plt_add_deps: :transitive,
       flags: [:unmatched_returns, :race_conditions, :error_handling, :underspecs]
     ],
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:redix, "~> 0.6"},
      {:connection, "~> 1.0.3"},

      {:ex_doc, "~> 0.16", only: :dev},
      {:mix_test_watch, "~> 0.2", only: :dev},
      {:toxiproxy, "~> 0.3", only: :test}
    ]
  end

  defp package do
    %{licenses: ["MIT"],
      links: %{"Github" => "https://github.com/ananthakumaran/redix_sentinel"},
      maintainers: ["ananthakumaran@gmail.com"]}
  end

  defp docs do
    [source_url: "https://github.com/ananthakumaran/redix_sentinel",
     source_ref: "v#{@version}",
     main: RedixSentinel,
     extras: ["README.md"]]
  end
end
