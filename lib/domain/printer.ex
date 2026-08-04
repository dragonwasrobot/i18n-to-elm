defmodule I18n2Elm.Domain.Printer do
  @moduledoc """
  Prints a list of `I18nResource` structs into a set of Elm i18n modules
  providing type-safe translation functionality.
  """

  @templates_location Application.compile_env(:i18n2elm, :templates_location)

  require Elixir.EEx
  alias I18n2Elm.Domain.I18nResource
  alias I18n2Elm.Domain.Locale
  alias I18n2Elm.Domain.PrinterViews.{IdsView, LanguageView, UtilView}

  @type reason :: :missing_reference_translation

  # {Output file path, file content}
  @type printed_file :: {Path.t(), String.t()}

  @language_location Path.join(@templates_location, "language.elm.eex")
  EEx.function_from_file(:defp, :language_template, @language_location, [
    :module_name,
    :file_name,
    :translation_name,
    :translations
  ])

  @ids_location Path.join(@templates_location, "ids.elm.eex")
  EEx.function_from_file(:defp, :ids_template, @ids_location, [:module_name, :ids])

  @util_location Path.join(@templates_location, "util.elm.eex")
  EEx.function_from_file(:defp, :util_template, @util_location, [
    :module_name,
    :imports,
    :languages
  ])

  @doc """
  Prints Elm i18n modules, `<Lang><Country>.elm` for a full set of languages,
  also produces the shared `Ids.elm` and `Utils.elm` modules that the language
  modules depend on.
  """
  @spec print_elm_i18n_modules([I18nResource.t()], String.t()) ::
          {:ok, [printed_file()]}
          | {:error, reason()}
  def print_elm_i18n_modules(translations, module_name) do
    case Enum.find(translations, &I18nResource.reference?/1) do
      nil ->
        {:error, :missing_reference_translation}

      reference_translation ->
        printed_translations = Enum.map(translations, &print_translation_module(&1, module_name))
        printed_ids = print_ids_module(reference_translation, module_name)
        printed_util = print_util_module(translations, module_name)

        {:ok, printed_translations ++ [printed_ids, printed_util]}
    end
  end

  @doc """
  Prints one language's Elm translation module: the `<Lang><Country>.elm` file
  exposing a `<lang><Country>Translations` function.
  """
  @spec print_translation_module(I18nResource.t(), String.t()) :: printed_file()
  def print_translation_module(translation, module_name) do
    file_name = create_file_name(translation)
    translation_name = create_translation_name(translation)
    file_path = create_file_path(file_name, module_name)

    translation_pairs =
      translation.translation_pairs
      |> Enum.map(&create_translation_pair/1)

    view = LanguageView.new(file_name, translation_name, translation_pairs)

    translation_file =
      language_template(
        module_name,
        view.file_name,
        view.translation_name,
        view.translation_pairs
      )

    {file_path, String.trim(translation_file) <> "\n"}
  end

  # Turns
  #     {"Hello", [{:text, "Hej, "},
  #                {:hole, 1},
  #                {:text, ". Leder du efter "},
  #                {:hole, 0},
  #                {:text, "?"}]}
  # into
  #     {"TidHello hole0 hole1",
  #      "\"Hej, \" ++ hole1 ++ \". Leder du efter \" ++ hole0 ++ \"?\""}.
  #
  # Hole numbering (not textual order) decides both the key's parameter
  # order and which `holeN` variable each quoted text sequence is joined against.
  @spec create_translation_pair(I18nResource.translation_pair()) :: {String.t(), String.t()}
  defp create_translation_pair({translation_key, translation}) do
    arguments = create_translation_arguments(translation)
    key = format_id_with_arguments(translation_key, arguments)
    value = Enum.map_join(translation, " ++ ", &quote_translation/1)
    {key, value}
  end

  @spec create_translation_arguments([I18nResource.translation_token()]) :: String.t()
  defp create_translation_arguments(translation) do
    translation
    |> Enum.filter(&hole?/1)
    |> Enum.sort(fn {:hole, hole1}, {:hole, hole2} -> hole1 < hole2 end)
    |> Enum.map(fn {:hole, hole_number} -> hole_number end)
    |> Enum.map_join(" ", fn hole_number -> "hole#{hole_number}" end)
  end

  @spec format_id_with_arguments(I18nResource.translation_key(), String.t()) :: String.t()
  defp format_id_with_arguments(translation_key, arguments) do
    String.trim("Tid#{translation_key} #{arguments}")
  end

  @spec hole?(I18nResource.translation_token()) :: boolean
  defp hole?({:hole, _hole_number}), do: true
  defp hole?({:text, _text}), do: false

  @spec quote_translation(I18nResource.translation_token()) :: String.t()
  defp quote_translation({:hole, hole_number}), do: "hole#{hole_number}"
  defp quote_translation({:text, text}), do: "\"#{text}\""

  @doc """
  Prints the shared `Ids.elm` file: the `TranslationId` union type derived
  from `reference_translation`.
  """
  @spec print_ids_module(I18nResource.t(), String.t()) :: printed_file()
  def print_ids_module(reference_translation, module_name) do
    file_name = "Ids"
    file_path = create_file_path(file_name, module_name)
    ids = build_ids(reference_translation)
    view = IdsView.new(ids)
    ids_file = ids_template(module_name, view.ids)

    {file_path, ids_file}
  end

  @spec build_ids(I18nResource.t()) :: [String.t()]
  defp build_ids(%I18nResource{translation_pairs: translation_pairs}) do
    Enum.map(translation_pairs, fn {translation_key, translation} ->
      arguments =
        translation
        |> Enum.filter(&hole?/1)
        |> Enum.map_join(" ", fn _ -> "String" end)

      format_id_with_arguments(translation_key, arguments)
    end)
  end

  @doc """
  Prints the shared `Util.elm` file: the `Language` union type plus the
  `parseLanguage`/`translate` dispatch functions across all `translations`.
  """
  @spec print_util_module([I18nResource.t()], String.t()) :: printed_file()
  def print_util_module(translations, module_name) do
    file_name = "Util"
    file_path = create_file_path(file_name, module_name)
    sorted_translations = Enum.sort(translations, &by_locale/2)

    imports = Enum.map(sorted_translations, &build_import/1)
    languages = Enum.map(sorted_translations, &build_language/1)
    view = UtilView.new(imports, languages)
    util_file = util_template(module_name, view.imports, view.languages)

    {file_path, util_file}
  end

  # Compares by {language, country}, not the %Locale{} structs themselves --
  # struct/map comparison in Elixir sorts by key name first (`country` before
  # `language`), which would sort by country and silently produce the wrong
  # order.
  @spec by_locale(I18nResource.t(), I18nResource.t()) :: boolean()
  defp by_locale(t1, t2) do
    {t1.locale.language, t1.locale.country} <= {t2.locale.language, t2.locale.country}
  end

  @spec build_import(I18nResource.t()) :: %{file_name: String.t(), translation_name: String.t()}
  defp build_import(translation) do
    %{
      file_name: create_file_name(translation),
      translation_name: create_translation_name(translation)
    }
  end

  @spec build_language(I18nResource.t()) :: map()
  defp build_language(%I18nResource{locale: locale} = translation) do
    locale_string = Locale.format(locale)

    %{
      string_value: locale_string,
      type_value: String.upcase(locale_string),
      translation_fun: create_translation_name(translation)
    }
  end

  @spec create_file_path(String.t(), String.t()) :: Path.t()
  defp create_file_path(file_name, module_name) do
    parts =
      if module_name != "" do
        [".", module_name, "#{file_name}.elm"]
      else
        [".", "#{file_name}.elm"]
      end

    Path.join(parts)
  end

  @spec create_file_name(I18nResource.t()) :: String.t()
  defp create_file_name(%I18nResource{locale: %Locale{language: language, country: country}}) do
    String.capitalize(language) <> String.capitalize(country)
  end

  @spec create_translation_name(I18nResource.t()) :: String.t()
  defp create_translation_name(%I18nResource{
         locale: %Locale{language: language, country: country}
       }) do
    language <> String.capitalize(country) <> "Translations"
  end
end
