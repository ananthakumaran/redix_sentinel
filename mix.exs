defmodule RedixSentinel.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :redix_sentinel,
     version: @version,
     elixir: "~> 1.2",
     description: "Redix with sentinel support",
     package: package(),
     docs: docs(),
     dialyzer: [
       plt_add_deps: :transitive,
       ignore_warnings: ".dialyzer_ignore",
       flags: [:unmatched_returns, :race_conditions, :error_handling, :underspecs]
     ],
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:redix, "~> 0.5"},
      {:connection, "~> 1.0.3"},

      {:ex_doc, "~> 0.16", only: :dev},
      {:mix_test_watch, "~> 0.2", only: :dev},
      {:toxiproxy, "~> 0.3", only: :test}
    ]
  end

  defp package do
    %{licenses: ["MIT"],
      links: %{"Github" => "https://github.com/ananthakumaran/redix-sentinel"},
      maintainers: ["ananthakumaran@gmail.com"]}
  end

  defp docs do
    [source_url: "https://github.com/ananthakumaran/redix-sentinel",
     source_ref: "v#{@version}",
     main: RedixSentinel,
     extras: ["README.md"]]
  end
end
