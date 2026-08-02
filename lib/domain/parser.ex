defmodule I18n2Elm.Domain.Parser do
  @moduledoc """
  Parses JSON i18n files into an intermediate representation to be used for
  e.g. printing Elm types and functions.
  """

  alias I18n2Elm.Domain.{Result, Types}
  alias I18n2Elm.Domain.Types.Translation

  @type reason ::
          {:invalid_hole_numbering, String.t()} | {:invalid_hole_placeholder, String.t()}

  @doc ~S"""
  Parses a map of translations of the format:

      %{"Yes" => "Ja",
        "No" => "Nej",
        "Hello" => "Hej, {0}. Leder du efter {1}?"}

  into a corresponding `Translation` struct.
  """
  @spec parse_translation(map, String.t()) :: {:ok, Translation.t()} | {:error, reason()}
  def parse_translation(translation_map, language_tag) do
    prefixed_translations =
      translation_map
      |> Enum.to_list()
      |> Enum.sort()
      |> Enum.map(fn {key, value} -> {"Tid#{key}", value} end)

    with {:ok, translations} <- Result.traverse(prefixed_translations, &check_for_holes/1),
         {:ok, _translation_ids} <- Result.traverse(translations, &validate_hole_numbering/1) do
      {:ok, Translation.new(translations, language_tag)}
    end
  end

  # Splitting on `{` and `}` turns "Hej, {0}. Leder..." into the alternating
  # list ["Hej, ", "0", ". Leder...", ...]; text and hole-number strings taking
  # turns. Chunking that two at a time regroups each text run with the hole
  # number immediately following it; the final chunk is a singleton exactly when
  # the value ends in plain text (no trailing hole).
  @spec check_for_holes({String.t(), String.t()}) ::
          {:ok, {String.t(), [Types.hole_token()]}} | {:error, reason()}
  defp check_for_holes({translation_id, text}) do
    hole_tokens_result = text |> split |> group |> Result.traverse(&to_hole_token/1)

    case hole_tokens_result do
      {:ok, text_with_holes} -> {:ok, {translation_id, text_with_holes}}
      {:error, :invalid_hole_placeholder} -> {:error, {:invalid_hole_placeholder, translation_id}}
    end
  end

  @spec split(String.t()) :: [String.t()]
  defp split(str), do: str |> String.split(~r/\{|\}/)

  @spec group([String.t()]) :: [[String.t()]]
  defp group(lst), do: lst |> Enum.chunk_every(2)

  @spec to_hole_token([String.t()]) ::
          {:ok, Types.hole_token()} | {:error, :invalid_hole_placeholder}
  defp to_hole_token([text]), do: {:ok, {:text, text}}

  defp to_hole_token([text, hole]) do
    case Integer.parse(hole) do
      {hole_number, ""} -> {:ok, {:hole, text, hole_number}}
      _ -> {:error, :invalid_hole_placeholder}
    end
  end

  # Validates that a translation value's hole numbers are exactly 0..n-1 once
  # sorted. This single check catches:
  # - gaps (e.g. {0},{2}),
  # - duplicates (e.g. {0} twice), and
  # - non-zero starts (e.g. only {1})
  # all at once, since each produces a sorted list that doesn't match the
  # expected 0..n-1 range.
  @spec validate_hole_numbering({String.t(), [Types.hole_token()]}) ::
          {:ok, String.t()} | {:error, reason()}
  defp validate_hole_numbering({translation_id, hole_tokens}) do
    hole_numbers =
      hole_tokens
      |> Enum.filter(&match?({:hole, _text, _hole_number}, &1))
      |> Enum.map(fn {:hole, _text, hole_number} -> hole_number end)
      |> Enum.sort()

    ordering = Enum.to_list(0..(length(hole_numbers) - 1)//1)
    contiguous_and_zero_indexed? = hole_numbers == ordering

    if contiguous_and_zero_indexed? do
      {:ok, translation_id}
    else
      {:error, {:invalid_hole_numbering, translation_id}}
    end
  end
end
