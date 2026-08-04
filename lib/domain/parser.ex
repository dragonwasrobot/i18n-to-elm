defmodule I18n2Elm.Domain.Parser do
  @moduledoc """
  Parses JSON i18n files into an `I18nResource` to be used downstream for code generation.
  """

  alias I18n2Elm.Domain.I18nResource
  alias I18n2Elm.Domain.Locale
  alias I18n2Elm.Result

  @type reason ::
          :missing_reference_translation
          | {:invalid_hole_numbering, I18nResource.translation_key()}
          | {:invalid_hole_placeholder, I18nResource.translation_key()}
          | {:mismatched_keys, Locale.t()}
          | {:invalid_locale, String.t()}

  @spec parse_translations([{String.t(), map()}]) ::
          {:ok, [I18nResource.t()]} | {:error, reason()}
  def parse_translations(raw_translations) do
    parser_result =
      Result.traverse(raw_translations, fn {filename, decoded} ->
        parse_translation(decoded, filename)
      end)

    with {:ok, translations} <- parser_result,
         :ok <- validate_reference_language_present(translations),
         :ok <- validate_matching_key_sets(translations) do
      {:ok, translations}
    end
  end

  @doc ~S"""
  Parses a map of translations of the format:

      %{"Yes" => "Ja",
        "No" => "Nej",
        "Hello" => "Hej, {0}. Leder du efter {1}?"}

  into a corresponding `I18nResource` struct.
  """
  @spec parse_translation(map, String.t()) :: {:ok, I18nResource.t()} | {:error, reason()}
  def parse_translation(translation_map, raw_locale) do
    sorted_translations = translation_map |> Enum.to_list() |> Enum.sort()

    with {:ok, locale} <- Locale.parse(raw_locale),
         {:ok, translations} <- Result.traverse(sorted_translations, &parse_value/1) do
      {:ok, I18nResource.new(translations, locale)}
    end
  end

  # Splitting on `{` and `}` turns "Hej, {0}. Leder..." into the alternating
  # list [{:text, "Hej"}, {:hole, 0}, {:text, ". Leder..."}, ...]; text tokens are
  # even indices, while hole tokens are odd indices. The resulting holes are
  # then checked for contiguous: 0-indexed with no duplicates or skips.
  @spec parse_value({String.t(), String.t()}) ::
          {:ok, {String.t(), [I18nResource.translation_token()]}} | {:error, reason()}
  defp parse_value({translation_key, text}) do
    with {:ok, tokens} <- tokenize(text, translation_key),
         translation_tokens <- Enum.reject(tokens, &empty_text?/1),
         :ok <- validate_hole_numbering(translation_tokens, translation_key) do
      {:ok, {translation_key, translation_tokens}}
    end
  end

  @spec tokenize(String.t(), String.t()) ::
          {:ok, [I18nResource.translation_token()]}
          | {:error, {:invalid_hole_placeholder, String.t()}}
  defp tokenize(text, translation_key) do
    text
    |> split_on_braces()
    |> Enum.with_index()
    |> Result.traverse(&tokenize_segment(&1, translation_key))
  end

  @spec split_on_braces(String.t()) :: [String.t()]
  defp split_on_braces(str), do: str |> String.split(~r/\{|\}/)

  @spec tokenize_segment({String.t(), non_neg_integer()}, String.t()) ::
          {:ok, I18nResource.translation_token()}
          | {:error, {:invalid_hole_placeholder, String.t()}}
  defp tokenize_segment({text, index}, _translation_key) when rem(index, 2) == 0,
    do: {:ok, {:text, text}}

  defp tokenize_segment({hole, _index}, translation_key) do
    case Integer.parse(hole) do
      {hole_number, ""} -> {:ok, {:hole, hole_number}}
      _ -> {:error, {:invalid_hole_placeholder, translation_key}}
    end
  end

  @spec empty_text?(I18nResource.translation_token()) :: boolean()
  defp empty_text?({:text, ""}), do: true
  defp empty_text?(_translation_token), do: false

  # Validates that a translation value's hole numbers are exactly 0..n-1 once
  # sorted. This single check catches:
  # - gaps (e.g. {0},{2}),
  # - duplicates (e.g. {0} twice), and
  # - non-zero starts (e.g. only {1})
  # all at once, since each produces a sorted list that doesn't match the
  # expected 0..n-1 range.
  @spec validate_hole_numbering([I18nResource.translation_token()], String.t()) ::
          :ok | {:error, reason()}
  defp validate_hole_numbering(translation_tokens, translation_key) do
    hole_numbers = extract_hole_numbers(translation_tokens)
    ordering = Enum.to_list(0..(length(hole_numbers) - 1)//1)
    contiguous_and_zero_indexed? = hole_numbers == ordering

    if contiguous_and_zero_indexed? do
      :ok
    else
      {:error, {:invalid_hole_numbering, translation_key}}
    end
  end

  @spec extract_hole_numbers([I18nResource.translation_token()]) :: [non_neg_integer()]
  defp extract_hole_numbers(tokens) do
    tokens
    |> Enum.filter(&match?({:hole, _hole_number}, &1))
    |> Enum.map(fn {:hole, hole_number} -> hole_number end)
    |> Enum.sort()
  end

  @spec validate_reference_language_present([I18nResource.t()]) ::
          :ok | {:error, :missing_reference_translation}
  defp validate_reference_language_present(translations) do
    if Enum.any?(translations, &I18nResource.reference?/1) do
      :ok
    else
      {:error, :missing_reference_translation}
    end
  end

  @spec validate_matching_key_sets([I18nResource.t()]) ::
          :ok | {:error, {:mismatched_keys, Locale.t()}}
  defp validate_matching_key_sets(translations) do
    reference_keys =
      translations
      |> Enum.find(&I18nResource.reference?/1)
      |> translation_keys()

    mismatch =
      translations
      |> Enum.reject(&I18nResource.reference?/1)
      |> Enum.find(&(not MapSet.equal?(translation_keys(&1), reference_keys)))

    case mismatch do
      nil -> :ok
      %I18nResource{locale: locale} -> {:error, {:mismatched_keys, locale}}
    end
  end

  @spec translation_keys(I18nResource.t()) :: MapSet.t(String.t())
  defp translation_keys(%I18nResource{translation_pairs: translation_pairs}) do
    translation_pairs
    |> Enum.map(fn {translation_key, _translation_tokens} -> translation_key end)
    |> MapSet.new()
  end
end
