defmodule I18n2Elm.Mixfile do
  use Mix.Project

  @version "1.0.0"
  @elixir_version "~> 1.8"

  def project do
    [
      app: :i18n2elm,
      version: @version,
      elixir: @elixir_version,
      aliases: aliases(),
      deps: deps(),
      description: description(),
      dialyzer: dialyzer(),
      docs: docs(),
      escript: escript(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp aliases do
    [
      build: ["deps.get", "compile", "escript.build"],
      check: ["credo --strict --ignore=RedundantBlankLines"]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19-rc", only: :dev, runtime: false},
      {:jason, "~> 1.1"}
    ]
  end

  defp description do
    """
    Generates Elm types and functions from i18n key/value JSON files.
    """
  end

  defp dialyzer do
    [plt_add_deps: :project]
  end

  defp docs do
    [
      name: "i18n to Elm",
      formatter_opts: [gfm: true],
      source_ref: @version,
      source_url: "https://github.com/dragonwasrobot/i18n-to-elm",
      extras: []
    ]
  end

  defp escript do
    [main_module: I18n2Elm, name: "i18n2elm"]
  end
end
