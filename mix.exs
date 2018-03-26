defmodule I18n2Elm.Mixfile do
  use Mix.Project

  def project do
    [
      app: :i18n2elm,
      version: "0.1.1",
      elixir: "~> 1.6",
      deps: deps(),
      aliases: aliases(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,

      # Packaging
      escript: [
        main_module: I18n2Elm,
        name: "i18n2elm"
      ],

      # Dialyxir
      dialyzer: [plt_add_deps: :project],

      # Docs
      name: "I18n2Elm",
      source_url: ""
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:poison, "~> 3.0"},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:credo, "~> 0.5", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:apex, "~>1.0.0"}
    ]
  end

  defp aliases do
    [
      build: ["deps.get", "compile", "escript.build"]
    ]
  end
end
