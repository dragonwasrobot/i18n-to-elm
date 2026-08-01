defmodule I18n2Elm.Printer do
  @moduledoc """
  Prints an intermediate representation of a JSON i18n file into a series
  of elm types and functions.
  """

  @templates_location Application.compile_env(:i18n2elm, :templates_location)
  @language_location Path.join(@templates_location, "language.elm.eex")
  @ids_location Path.join(@templates_location, "ids.elm.eex")
  @util_location Path.join(@templates_location, "util.elm.eex")

  require Elixir.EEx
  alias I18n2Elm.Result
  alias I18n2Elm.Types
  alias I18n2Elm.Types.Translation

  @type reason :: :invalid_language_tag | :missing_reference_translation

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

  @spec print_translations([Translation.t()], String.t()) ::
          {:ok, [Types.printed_file()]} | {:error, reason()}
  def print_translations(translations, module_name) do
    with {:ok, printed_translations} <-
           Result.traverse(translations, &print_translation(&1, module_name)),
         {:ok, printed_ids} <- print_ids(translations, module_name),
         {:ok, printed_util} <- print_util(translations, module_name) do
      {:ok, printed_translations ++ [printed_ids] ++ [printed_util]}
    end
  end

  @doc """
  Prints one language's Elm translation module: the `<Lang><Country>.elm` file
  exposing a `<lang><Country>Translations` function. Reach for
  `print_translations/2` instead when printing a full set of languages, since
  it also produces the shared `Ids.elm` and `Util.elm` files this module's
  output depends on.
  """
  @spec print_translation(Translation.t(), String.t()) ::
          {:ok, Types.printed_file()} | {:error, :invalid_language_tag}
  def print_translation(translation, module_name) do
    with {:ok, file_name} <- create_file_name(translation),
         {:ok, translation_name} <- create_translation_name(translation) do
      file_path = create_file_path(file_name, module_name)

      translations =
        translation.translations
        |> Enum.map(&create_translation_pair/1)

      translation_file = language_template(module_name, file_name, translation_name, translations)

      {:ok, {file_path, String.trim(translation_file) <> "\n"}}
    end
  end

  # Turns
  #     {"TidHello", [{:hole, "Hej, ", 1},
  #                   {:hole, ". Leder du efter ", 0},
  #                   {:text, "?"}]}
  # into
  #     {"TidHello hole0 hole1",
  #      "\"Hej, \" ++ hole1 ++ \". Leder du efter \" ++ hole0 ++ \"?\""}.
  #
  # Hole numbering (not textual order) decides both the key's parameter
  # order and which `holeN` variable each quoted text sequence is joined against.
  @spec create_translation_pair({String.t(), [Types.hole_token()]}) :: {String.t(), String.t()}
  defp create_translation_pair({translation_id, translation}) do
    arguments = create_translation_arguments(translation)
    key = format_id_with_arguments(translation_id, arguments)
    value = create_translation_value(translation)

    {key, value}
  end

  @spec create_translation_arguments([Types.hole_token()]) :: String.t()
  defp create_translation_arguments(translation) do
    translation
    |> Enum.filter(&hole?/1)
    |> Enum.sort(fn {:hole, _text1, hole1}, {:hole, _text2, hole2} -> hole1 < hole2 end)
    |> Enum.map(fn {:hole, _text, hole_number} -> hole_number end)
    |> Enum.map_join(" ", fn hole_number -> "hole#{hole_number}" end)
  end

  @spec format_id_with_arguments(String.t(), String.t()) :: String.t()
  defp format_id_with_arguments(translation_id, arguments) do
    String.trim("#{translation_id} #{arguments}")
  end

  @spec hole?(Types.hole_token()) :: boolean
  defp hole?({:hole, _text, _hole_number}), do: true
  defp hole?({:text, _text}), do: false

  @spec create_translation_value([Types.hole_token()]) :: String.t()
  defp create_translation_value(translation) do
    translation
    |> Enum.map(&quote_translation/1)
    |> Enum.map(&Tuple.to_list/1)
    |> List.flatten()
    |> Enum.join(" ++ ")
  end

  @spec quote_translation(Types.hole_token()) :: {String.t(), String.t()} | {String.t()}
  defp quote_translation({:hole, text, hole_number}) do
    {"\"#{text}\"", "hole#{hole_number}"}
  end

  defp quote_translation({:text, text}), do: {"\"#{text}\""}

  @spec print_ids([Translation.t()], String.t()) ::
          {:ok, Types.printed_file()} | {:error, :missing_reference_translation}
  def print_ids(translations, module_name) do
    file_name = "Ids"
    file_path = create_file_path(file_name, module_name)

    case Enum.find(translations, &reference_translation?/1) do
      nil ->
        {:error, :missing_reference_translation}

      reference_translation ->
        ids = build_ids(reference_translation)
        ids_file = ids_template(module_name, ids)

        {:ok, {file_path, ids_file}}
    end
  end

  @spec build_ids(Translation.t()) :: [String.t()]
  defp build_ids(%Translation{translations: translations}) do
    Enum.map(translations, fn {translation_id, translation} ->
      arguments =
        translation
        |> Enum.filter(&hole?/1)
        |> Enum.map_join(" ", fn _ -> "String" end)

      format_id_with_arguments(translation_id, arguments)
    end)
  end

  @spec reference_translation?(Translation.t()) :: boolean
  defp reference_translation?(%Translation{language_tag: language_tag}) do
    language_tag == Types.reference_language_tag()
  end

  @spec print_util([Translation.t()], String.t()) ::
          {:ok, Types.printed_file()} | {:error, :invalid_language_tag}
  def print_util(translations, module_name) do
    file_name = "Util"
    file_path = create_file_path(file_name, module_name)
    sorted_translations = Enum.sort(translations, &by_language_tag/2)

    with {:ok, imports} <- Result.traverse(sorted_translations, &build_import/1),
         {:ok, languages} <- Result.traverse(sorted_translations, &build_language/1) do
      util_file = util_template(module_name, imports, languages)
      {:ok, {file_path, util_file}}
    end
  end

  @spec by_language_tag(Translation.t(), Translation.t()) :: boolean()
  defp by_language_tag(t1, t2), do: t1.language_tag <= t2.language_tag

  @spec build_import(Translation.t()) :: {:ok, map} | {:error, :invalid_language_tag}
  defp build_import(translation) do
    with {:ok, file_name} <- create_file_name(translation),
         {:ok, translation_name} <- create_translation_name(translation) do
      {:ok, %{file_name: file_name, translation_name: translation_name}}
    end
  end

  @spec build_language(Translation.t()) :: {:ok, map()} | {:error, :invalid_language_tag}
  defp build_language(%Translation{language_tag: language_tag} = translation) do
    with {:ok, translation_name} <- create_translation_name(translation) do
      {:ok,
       %{
         string_value: language_tag,
         type_value: String.upcase(language_tag),
         translation_fun: translation_name
       }}
    end
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

  @spec create_file_name(Translation.t()) :: {:ok, String.t()} | {:error, :invalid_language_tag}
  defp create_file_name(%Translation{language_tag: language_tag}) do
    with {:ok, {language, country}} <- split_language_tag(language_tag) do
      {:ok, String.capitalize(language) <> String.capitalize(country)}
    end
  end

  @spec split_language_tag(String.t()) ::
          {:ok, {String.t(), String.t()}} | {:error, :invalid_language_tag}
  defp split_language_tag(language_tag) do
    case String.split(language_tag, "_") do
      [language, country] -> {:ok, {language, country}}
      _ -> {:error, :invalid_language_tag}
    end
  end

  @spec create_translation_name(Translation.t()) ::
          {:ok, String.t()} | {:error, :invalid_language_tag}
  defp create_translation_name(%Translation{language_tag: language_tag}) do
    with {:ok, {language, country}} <- split_language_tag(language_tag) do
      {:ok, language <> String.capitalize(country) <> "Translations"}
    end
  end
end
