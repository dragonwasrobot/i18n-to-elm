defmodule I18n2Elm.Parser do
  @moduledoc ~S"""
  Parses JSON i18n files into an intermediate representation to be used for
  e.g. printing elm types and functions.
  """

  require Logger
  alias I18n2Elm.Types.Translation

  @spec parse_translation_files([String.t]) :: [Translation.t]
  def parse_translation_files(translation_file_paths) do
    translation_file_paths
    |> Enum.map(&(parse_translation_file(&1)))
  end

  @spec parse_translation_file(String.t) :: Translation.t
  def parse_translation_file(translation_file_path) do
    language_tag = Path.basename(translation_file_path, ".json")

    translation_file_path
    |> File.read!
    |> Poison.decode!
    |> parse_translation(language_tag)
  end

  @spec parse_translation(map, String.t) :: Translation.t
  def parse_translation(translation_node, language_tag) do
    translations =
      translation_node
      |> Enum.to_list
      |> Enum.sort
      |> Enum.map(fn {key, value} -> {"Tid#{key}", value} end)

    Translation.new(language_tag, translations)
  end

end
