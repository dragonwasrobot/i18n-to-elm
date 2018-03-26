defmodule I18n2Elm.Printer do
  @moduledoc ~S"""
  Prints an intermediate representation of a JSON i18n file into a series
  of elm types and functions.
  """

  @templates_location Application.get_env(:i18n2elm, :templates_location)
  @language_location Path.join(@templates_location, "language.elm.eex")
  @ids_location Path.join(@templates_location, "ids.elm.eex")
  @util_location Path.join(@templates_location, "util.elm.eex")

  require Elixir.{EEx, Logger}
  alias I18n2Elm.Types.{Translation, LanguageResource, IdsResource, UtilResource}

  EEx.function_from_file(:defp, :language_template, @language_location, [
    :module_name,
    :file_name,
    :translation_name,
    :translations
  ])

  EEx.function_from_file(:defp, :ids_template, @ids_location, [:module_name, :ids])

  EEx.function_from_file(:defp, :util_template, @util_location, [
    :module_name,
    :imports,
    :languages
  ])

  @spec print_translations([Translation.t()], String.t()) :: [{String.t(), String.t()}]
  def print_translations(translations, module_name \\ "") do
    printed_translations =
      translations
      |> Enum.map(&print_translation(&1, module_name))

    printed_ids = print_ids(translations, module_name)
    printed_util = print_util(translations, module_name)

    printed_translations ++ [printed_ids] ++ [printed_util]
  end

  @doc ~S"""
  Create translation keys and values

  """
  @spec print_translation(%Translation{}, String.t()) :: {String.t(), String.t()}
  def print_translation(translation, module_name \\ "") do
    file_name = create_file_name(translation)
    file_path = create_file_path(file_name, module_name)
    translation_name = create_translation_name(translation)

    translations =
      translation.translations
      |> Enum.map(&create_translation_pair/1)

    translation_file = language_template(module_name, file_name, translation_name, translations)

    {file_path, String.trim(translation_file) <> "\n"}
  end

  @doc ~S"""
  Creates a translation {key, value} pair:

      ## Examples

      iex> translation = {"TidHello", [{"Hej, ", 1},
      ...>                             {". Leder du efter ", 0},
      ...>                             {"?"}]}
      iex> create_translation_pair(translation)
      {"TidHello hole0 hole1",
       "\"Hej, \" ++ hole1 ++ \". Leder du efter \" ++ hole0 ++ \"?\""}
  """
  @spec create_translation_pair({String.t(), [{String.t(), integer} | {String.t()}]}) ::
          {String.t(), String.t()}
  defp create_translation_pair({translation_id, translation}) do
    arguments = create_translation_arguments(translation)

    key =
      if String.length(arguments) > 0 do
        "#{translation_id} #{arguments}"
      else
        translation_id
      end

    value = create_translation_value(translation)

    {key, value}
  end

  defp create_translation_arguments(translation) do
    translation
    |> Enum.filter(&two_tuple?/1)
    |> Enum.sort(fn {_t1, hole1}, {_t2, hole2} -> hole1 < hole2 end)
    |> Enum.map(fn {_text, hole_number} -> hole_number end)
    |> Enum.map_join(" ", fn hole_number -> "hole#{hole_number}" end)
  end

  defp two_tuple?({_left, _right}), do: true
  defp two_tuple?(_), do: false

  defp create_translation_value(translation) do
    translation
    |> Enum.map(&quote_translation/1)
    |> Enum.map(&Tuple.to_list/1)
    |> List.flatten()
    |> Enum.join(" ++ ")
  end

  defp quote_translation({text, hole_number}) do
    {"\"#{text}\"", "hole#{hole_number}"}
  end

  defp quote_translation({text}), do: {"\"#{text}\""}

  @spec print_ids([Translation.t()], String.t()) :: {String.t(), String.t()}
  def print_ids(translations, module_name \\ "") do
    file_name = "Ids"
    file_path = create_file_path(file_name, module_name)

    en_us_translation =
      translations
      |> Enum.find(&(&1.language_tag == "en_US"))

    ids =
      en_us_translation.translations
      |> Enum.map(fn {translation_id, translation} ->
        arguments =
          translation
          |> Enum.filter(&two_tuple?/1)
          |> Enum.map_join(" ", fn _ -> "String" end)

        if String.length(arguments) > 0 do
          "#{translation_id} #{arguments}"
        else
          translation_id
        end
      end)

    ids_file = ids_template(module_name, ids)

    {file_path, ids_file}
  end

  @spec print_util([Translation.t()], String.t()) :: {String.t(), String.t()}
  def print_util(translations, module_name \\ "") do
    file_name = "Util"
    file_path = create_file_path(file_name, module_name)

    imports =
      translations
      |> Enum.sort(&by_language_tag/2)
      |> Enum.map(fn translation ->
        %{
          file_name: create_file_name(translation),
          translation_name: create_translation_name(translation)
        }
      end)

    languages =
      translations
      |> Enum.sort(&by_language_tag/2)
      |> Enum.map(fn translation ->
        %{
          string_value: translation.language_tag,
          type_value: String.upcase(translation.language_tag),
          translation_fun: create_translation_name(translation)
        }
      end)

    util_file = util_template(module_name, imports, languages)

    {file_path, util_file}
  end

  defp by_language_tag(t1, t2), do: t1.language_tag <= t2.language_tag

  @spec create_file_path(String.t(), String.t()) :: String.t()
  defp create_file_path(file_name, module_name) do
    if module_name != "" do
      "./#{module_name}/#{file_name}.elm"
    else
      "./#{file_name}.elm"
    end
  end

  @spec create_file_name(Translation.t()) :: String.t()
  defp create_file_name(%Translation{language_tag: language_tag}) do
    [language, country] = String.split(language_tag, "_")
    String.capitalize(language) <> String.capitalize(country)
  end

  @spec create_translation_name(Translation.t()) :: String.t()
  defp create_translation_name(%Translation{language_tag: language_tag}) do
    [language, country] = String.split(language_tag, "_")
    language <> String.capitalize(country) <> "Translations"
  end
end
