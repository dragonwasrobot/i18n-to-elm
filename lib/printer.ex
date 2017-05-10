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
  alias I18n2Elm.Types.{Translation, LanguageResource,
                        IdsResource, UtilResource}

  EEx.function_from_file(:defp, :language_template, @language_location,
    [:module_name, :file_name, :translation_name, :translations])

  EEx.function_from_file(:defp, :ids_template, @ids_location,
    [:module_name, :ids])

  EEx.function_from_file(:defp, :util_template, @util_location,
    [:module_name, :imports, :languages])

  @spec print_translations([Translation.t], String.t) :: [{String.t, String.t}]
  def print_translations(translations, module_name \\ "") do

    printed_translations =
      translations
      |> Enum.map(&(print_translation(&1, module_name)))

    printed_ids = print_ids(translations, module_name)
    printed_util = print_util(translations, module_name)

    printed_translations ++ [printed_ids] ++ [printed_util]
  end

  @spec print_translation(%Translation{}, String.t) :: {String.t, String.t}
  def print_translation(translation, module_name \\ "") do

    file_name = create_file_name(translation)
    file_path = create_file_path(file_name, module_name)
    translation_name = create_translation_name(translation)
    translations = translation.translations

    translation_file =
      language_template(module_name, file_name, translation_name, translations)

    {file_path, translation_file}
  end

  @spec print_ids([Translation.t], String.t) :: {String.t, String.t}
  def print_ids(translations, module_name \\ "") do
    file_name = "Ids"
    file_path = create_file_path(file_name, module_name)

    en_us_translation =
      translations
      |> Enum.find(&(&1.language_tag == "en_US"))

    ids =
      en_us_translation.translations
      |> Enum.map(fn {id, _value} -> id end)

    ids_file =
      ids_template(module_name, ids)

    {file_path, ids_file}
  end

  @spec print_util([Translation.t], String.t) :: {String.t, String.t}
  def print_util(translations, module_name \\ "") do
    file_name = "Util"
    file_path = create_file_path(file_name, module_name)

    imports =
      translations
      |> Enum.map(fn translation ->
      %{file_name: create_file_name(translation),
        translation_name: create_translation_name(translation)}
    end)

    languages =
        translations
        |> Enum.map(fn translation ->
      %{string_value: translation.language_tag,
        type_value: String.upcase(translation.language_tag),
        translation_fun: create_translation_name(translation)}
    end)

    util_file = util_template(module_name, imports, languages)

    {file_path, util_file}
  end

  @spec create_file_path(String.t, String.t) :: String.t
  defp create_file_path(file_name, module_name) do
    if module_name != "" do
      "./#{module_name}/#{file_name}.elm"
    else
      "./#{file_name}.elm"
    end
  end

  @spec create_file_name(Translation.t) :: String.t
  defp create_file_name(%Translation{language_tag: language_tag}) do
    [language, country] = String.split(language_tag, "_")
    String.capitalize(language) <> String.capitalize(country)
  end

  @spec create_translation_name(Translation.t) :: String.t
  defp create_translation_name(%Translation{language_tag: language_tag}) do
    [language, country] = String.split(language_tag, "_")
    language <> String.capitalize(country) <> "Translations"
  end

end
