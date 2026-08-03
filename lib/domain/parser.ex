defmodule I18n2Elm.Domain.Parser do
  @moduledoc """
  Parses JSON i18n files into an intermediate representation to be used for e.g.
  printing Elm types and functions.
  """

  alias I18n2Elm.Domain.Types
  alias I18n2Elm.Domain.Types.Translation
  alias I18n2Elm.Result

  @type reason ::
          :missing_reference_translation
          | {:invalid_hole_numbering, String.t()}
          | {:invalid_hole_placeholder, String.t()}
          | {:mismatched_keys, Types.language_tag()}

  @spec parse_translations([{String.t(), map()}]) ::
          {:ok, [Translation.t()]} | {:error, reason()}
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

  into a corresponding `Translation` struct.
  """
  @spec parse_translation(map, String.t()) :: {:ok, Translation.t()} | {:error, reason()}
  def parse_translation(translation_map, language_tag) do
    prefixed_translations = prefix_translation_ids(translation_map)

    with {:ok, translations} <- Result.traverse(prefixed_translations, &parse_value/1) do
      {:ok, Translation.new(translations, language_tag)}
    end
  end

  @spec prefix_translation_ids(map) :: [{String.t(), String.t()}]
  defp prefix_translation_ids(translation_map) do
    translation_map
    |> Enum.to_list()
    |> Enum.sort()
    |> Enum.map(fn {key, value} -> {"Tid#{key}", value} end)
  end

  # Splitting on `{` and `}` turns "Hej, {0}. Leder..." into the alternating
  # list [{:text, "Hej"}, {:hole, 0}, {:text, ". Leder..."}, ...]; text runs are
  # even indices, while hole runs are odd indices. The resulting tokens are
  # then checked for contiguous, 0-indexed hole numbering.
  @spec parse_value({String.t(), String.t()}) ::
          {:ok, {String.t(), [Types.translation_token()]}} | {:error, reason()}
  defp parse_value({translation_id, text}) do
    with {:ok, tokens} <- tokenize(text, translation_id),
         translation_tokens <- Enum.reject(tokens, &empty_text?/1),
         :ok <- validate_hole_numbering(translation_tokens, translation_id) do
      {:ok, {translation_id, translation_tokens}}
    end
  end

  @spec tokenize(String.t(), String.t()) ::
          {:ok, [Types.translation_token()]}
          | {:error, {:invalid_hole_placeholder, String.t()}}
  defp tokenize(text, translation_id) do
    text
    |> split()
    |> Enum.with_index()
    |> Result.traverse(&tokenize_segment(&1, translation_id))
  end

  @spec split(String.t()) :: [String.t()]
  defp split(str), do: str |> String.split(~r/\{|\}/)

  @spec tokenize_segment({String.t(), non_neg_integer()}, String.t()) ::
          {:ok, Types.translation_token()}
          | {:error, {:invalid_hole_placeholder, String.t()}}
  defp tokenize_segment({text, index}, _translation_id) when rem(index, 2) == 0,
    do: {:ok, {:text, text}}

  defp tokenize_segment({hole, _index}, translation_id) do
    case Integer.parse(hole) do
      {hole_number, ""} -> {:ok, {:hole, hole_number}}
      _ -> {:error, {:invalid_hole_placeholder, translation_id}}
    end
  end

  @spec empty_text?(Types.translation_token()) :: boolean
  defp empty_text?({:text, ""}), do: true
  defp empty_text?(_translation_token), do: false

  # Validates that a translation value's hole numbers are exactly 0..n-1 once
  # sorted. This single check catches:
  # - gaps (e.g. {0},{2}),
  # - duplicates (e.g. {0} twice), and
  # - non-zero starts (e.g. only {1})
  # all at once, since each produces a sorted list that doesn't match the
  # expected 0..n-1 range.
  @spec validate_hole_numbering([Types.translation_token()], String.t()) ::
          :ok | {:error, reason()}
  defp validate_hole_numbering(translation_tokens, translation_id) do
    hole_numbers = extract_hole_numbers(translation_tokens)
    ordering = Enum.to_list(0..(length(hole_numbers) - 1)//1)
    contiguous_and_zero_indexed? = hole_numbers == ordering

    if contiguous_and_zero_indexed? do
      :ok
    else
      {:error, {:invalid_hole_numbering, translation_id}}
    end
  end

  @spec extract_hole_numbers([Types.translation_token()]) :: [non_neg_integer()]
  defp extract_hole_numbers(tokens) do
    tokens
    |> Enum.filter(&match?({:hole, _hole_number}, &1))
    |> Enum.map(fn {:hole, hole_number} -> hole_number end)
    |> Enum.sort()
  end

  @spec validate_reference_language_present([Translation.t()]) ::
          :ok | {:error, :missing_reference_translation}
  defp validate_reference_language_present(translations) do
    if Enum.any?(translations, &reference_translation?/1) do
      :ok
    else
      {:error, :missing_reference_translation}
    end
  end

  @spec validate_matching_key_sets([Translation.t()]) ::
          :ok | {:error, {:mismatched_keys, Types.language_tag()}}
  defp validate_matching_key_sets(translations) do
    reference_keys =
      translations
      |> Enum.find(&reference_translation?/1)
      |> translation_keys()

    translations
    |> Enum.reject(&reference_translation?/1)
    |> Enum.find(&(not MapSet.equal?(translation_keys(&1), reference_keys)))
    |> case do
      nil -> :ok
      %Translation{language_tag: language_tag} -> {:error, {:mismatched_keys, language_tag}}
    end
  end

  @spec reference_translation?(Translation.t()) :: boolean
  defp reference_translation?(%Translation{language_tag: language_tag}) do
    language_tag == Types.reference_language_tag()
  end

  @spec translation_keys(Translation.t()) :: MapSet.t(String.t())
  defp translation_keys(%Translation{translations: translations}) do
    translations
    |> Enum.map(fn {translation_id, _translation_tokens} -> translation_id end)
    |> MapSet.new()
  end
end
