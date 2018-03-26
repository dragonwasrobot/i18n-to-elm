defmodule I18n2Elm.Parser do
  @moduledoc ~S"""
  Parses JSON i18n files into an intermediate representation to be used for
  e.g. printing elm types and functions.
  """

  require Logger
  alias I18n2Elm.Types.Translation

  @spec parse_translation_files([String.t()]) :: [Translation.t()]
  def parse_translation_files(translation_file_paths) do
    translation_file_paths
    |> Enum.map(&parse_translation_file(&1))
  end

  @spec parse_translation_file(String.t()) :: Translation.t()
  def parse_translation_file(translation_file_path) do
    language_tag = Path.basename(translation_file_path, ".json")

    translation_file_path
    |> File.read!()
    |> Poison.decode!()
    |> parse_translation(language_tag)
  end

  @doc ~S"""
  Parses a map of translations into a `Translation` struct.

  ## Examples

      iex> translation = %{"Yes" => "Ja",
      ...>                 "No" => "Nej",
      ...>                 "Next" => "Næste",
      ...>                 "Previous" => "Forrige",
      ...>                 "Hello" => "Hej, {0}. Leder du efter {1}?"}
      iex> parse_translation(translation, "da_DK")
      %I18n2Elm.Types.Translation{
          language_tag: "da_DK",
          translations: [
              {"TidHello", [{"Hej, ", 0},
                            {". Leder du efter ", 1},
                            {"?"}]},
              {"TidNext", [{"Næste"}]},
              {"TidNo", [{"Nej"}]},
              {"TidPrevious", [{"Forrige"}]},
              {"TidYes", [{"Ja"}]}
      ]}
  """
  @spec parse_translation(map, String.t()) :: Translation.t()
  def parse_translation(translation_node, language_tag) do
    translations =
      translation_node
      |> Enum.to_list()
      |> Enum.sort()
      |> Enum.map(&check_for_holes/1)
      |> Enum.map(fn {key, value} -> {"Tid#{key}", value} end)

    Translation.new(language_tag, translations)
  end

  defp check_for_holes({key, text}) do
    text_with_holes =
      text
      |> split
      |> group
      |> Enum.map(&tuplify/1)
      |> Enum.map(&hole_to_number/1)

    {key, text_with_holes}
  end

  defp split(str), do: str |> String.split(~r/\{|\}/)

  defp group(lst), do: lst |> Enum.chunk_every(2)

  defp tuplify(lst), do: lst |> List.to_tuple()

  defp hole_to_number({text, hole}) do
    {text}
    |> Tuple.append(hole |> Integer.parse() |> elem(0))
  end

  defp hole_to_number({text}), do: {text}
end
