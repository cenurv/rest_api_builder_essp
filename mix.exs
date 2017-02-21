defmodule RestApiBuilderEssp.Mixfile do
  use Mix.Project

  @version "0.5.2"

  def project do
    [app: :rest_api_builder_essp,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: "A provider for REST API Builder that uses Ecto Schema Store to provide resources.",
     name: "REST API Builder - Ecto Schema Store Provider",
     package: %{
       licenses: ["Apache 2.0"],
       maintainers: ["Joseph Lindley"],
       links: %{"GitHub" => "https://github.com/cenurv/rest_api_builder_essp"},
       files: ~w(mix.exs README.md CHANGELOG.md lib)
     },
     docs: [source_ref: "v#{@version}", main: "readme",
            canonical: "http://hexdocs.pm/rest_api_builder_essp",
            source_url: "https://github.com/cenurv/rest_api_builder_essp",
            extras: ["CHANGELOG.md", "README.md"]]]
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
    [{:ex_doc, "~> 0.14", only: [:docs, :dev]},
     {:rest_api_builder, "~> 0.5"},
     {:ecto_schema_store, "~> 1.8"}]
  end
end
