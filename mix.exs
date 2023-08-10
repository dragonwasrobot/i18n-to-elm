defmodule I18n2Elm.MixProject do
  use Mix.Project

  @version "0.2.0"
  @elixir_version "~> 1.14"

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
      preferred_cli_env: preferred_cli_env(),
      test_coverage: test_coverage(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [extra_applications: [:logger, :eex]]
  end

  defp aliases do
    [
      build: ["deps.get", "compile", "escript.build"]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:excoveralls, "~> 0.17.0", only: :test, runtime: false},
      {:jason, "~> 1.4"},
      {:typed_struct, "~> 0.3.0"}
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

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  end

  defp test_coverage do
    [tool: ExCoveralls]
  end
end
