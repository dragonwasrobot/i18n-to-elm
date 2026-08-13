defmodule I18n2Elm.Domain.Printer do
  @moduledoc """
  Prints a list of `I18nResource` structs into a set of Elm i18n modules
  providing type-safe translation functionality.
  """

  require Elixir.EEx
  alias I18n2Elm.Domain.Parser.{I18nResource, Locale}
  alias I18n2Elm.Domain.Printer.{I18nTextView, IdsView, LanguageView, UtilView}

  # {Output file path, file content}
  @type printed_file :: {Path.t(), String.t()}

  @templates_location Application.compile_env(:i18n2elm, :templates_location)

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

  @i18n_text_location Path.join(@templates_location, "i18n_text.elm.eex")
  EEx.function_from_file(:defp, :i18n_text_template, @i18n_text_location, [
    :module_name,
    :clauses
  ])

  # Not templated as nothing in it varies per project.
  @web_component_js_path @templates_location
                         |> Path.join("../web-component/i18n-text.js")
                         |> Path.expand()
  @external_resource @web_component_js_path
  @web_component_source File.read!(@web_component_js_path)

  @doc """
  Prints `native` mode's file set: `<Lang><Country>.elm` for a full set of
  languages, plus the shared `Ids.elm` and `Util.elm` modules that the
  language modules depend upon.
  """
  @spec print_native_modules([I18nResource.t()], I18nResource.t(), String.t()) :: [printed_file()]
  def print_native_modules(translations, reference_translation, module_name) do
    printed_ids = print_ids_module(reference_translation, module_name)
    printed_util = print_util_module(translations, module_name)
    printed_translations = Enum.map(translations, &print_translation_module(&1, module_name))

    printed_translations ++ [printed_ids, printed_util]
  end

  @doc """
  Prints the `web-component` mode's file set: `Ids.elm` and `I18nText.elm` plus
  the `static/` runtime assets (per-locale JSON, `locales.json`, and the
  `<i18n-text>` module) they depend upon.
  """
  @spec print_web_component_modules([I18nResource.t()], I18nResource.t(), String.t()) :: [
          printed_file()
        ]
  def print_web_component_modules(translations, reference_translation, module_name) do
    printed_ids = print_ids_module(reference_translation, module_name)
    printed_i18n_text = print_i18n_text_module(reference_translation, module_name)
    printed_locale_jsons = Enum.map(translations, &print_locale_json/1)
    printed_locales_manifest = print_locales_manifest(translations)
    printed_script = print_web_component_script()

    [printed_ids, printed_i18n_text, printed_locales_manifest, printed_script] ++
      printed_locale_jsons
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
    Enum.join(extract_hole_variables(translation), " ")
  end

  # Turns a translation's hole tokens into their `holeN` Elm variable names, in
  # ascending hole-number order.
  @spec extract_hole_variables([I18nResource.translation_token()]) :: [String.t()]
  defp extract_hole_variables(translation) do
    translation
    |> Enum.filter(&hole?/1)
    |> Enum.sort(fn {:hole, hole1}, {:hole, hole2} -> hole1 < hole2 end)
    |> Enum.map(fn {:hole, hole_number} -> "hole#{hole_number}" end)
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

  @doc """
  Prints the `web-component` mode's `I18nText.elm` file: a single
  `view` function dispatching every `TranslationId` to an `<i18n-text>`
  custom element, derived from `reference_translation`.
  """
  @spec print_i18n_text_module(I18nResource.t(), String.t()) :: printed_file()
  def print_i18n_text_module(reference_translation, module_name) do
    file_name = "I18nText"
    file_path = create_file_path(file_name, module_name)
    clauses = build_clauses(reference_translation)
    view = I18nTextView.new(clauses)
    i18n_text_file = i18n_text_template(module_name, view.clauses)

    {file_path, String.trim(i18n_text_file) <> "\n"}
  end

  @spec build_clauses(I18nResource.t()) :: [I18nTextView.clause()]
  defp build_clauses(%I18nResource{translation_pairs: translation_pairs}) do
    Enum.map(translation_pairs, fn {translation_key, translation} ->
      arguments = create_translation_arguments(translation)
      pattern = format_id_with_arguments(translation_key, arguments)
      values_expr = create_values_expression(translation)

      %{pattern: pattern, key: translation_key, values_expr: values_expr}
    end)
  end

  @spec create_values_expression([I18nResource.translation_token()]) :: String.t()
  defp create_values_expression(translation) do
    case extract_hole_variables(translation) do
      [] -> "[]"
      hole_vars -> "[ " <> Enum.join(hole_vars, ", ") <> " ]"
    end
  end

  @doc """
  Prints one locale's runtime JSON asset. Reconstructs the original
  `{0}`/`{1}`-style JSON from `translation`'s already-tokenized
  `translation_pairs`.
  """
  @spec print_locale_json(I18nResource.t()) :: printed_file()
  def print_locale_json(%I18nResource{locale: locale} = translation) do
    file_path = create_static_asset_path(Locale.format(locale), "json")

    json_file =
      translation.translation_pairs
      |> Enum.map(fn {translation_key, tokens} ->
        {translation_key, Enum.map_join(tokens, &reconstruct_token/1)}
      end)
      |> Jason.OrderedObject.new()
      |> Jason.encode!(pretty: true)

    {file_path, json_file <> "\n"}
  end

  @spec reconstruct_token(I18nResource.translation_token()) :: String.t()
  defp reconstruct_token({:text, text}), do: text
  defp reconstruct_token({:hole, hole_number}), do: "{#{hole_number}}"

  @doc """
  Prints `locales.json`, the manifest of available locale tags. Used at runtime
  to resolve a browser's requested language against the shipped per-locale JSON
  assets.
  """
  @spec print_locales_manifest([I18nResource.t()]) :: printed_file()
  def print_locales_manifest(translations) do
    file_path = create_static_asset_path("locales", "json")

    locale_tags =
      translations
      |> Enum.map(&Locale.format(&1.locale))
      |> Enum.sort()

    {file_path, Jason.encode!(locale_tags) <> "\n"}
  end

  @doc """
  Prints the `<i18n-text>` custom element script, embedded at compile time from
  `priv/web-component/i18n-text.js`.
  """
  @spec print_web_component_script() :: printed_file()
  def print_web_component_script do
    {create_static_asset_path("i18n-text", "js"), @web_component_source}
  end

  # Static assets are served as-is, not compiled, so they live under a
  # fixed `static/` root sibling to the `<module-name>/` Elm directory.
  @spec create_static_asset_path(String.t(), String.t()) :: Path.t()
  defp create_static_asset_path(file_name, ext) do
    Path.join([".", "static", "#{file_name}.#{ext}"])
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
