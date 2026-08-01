defmodule I18n2Elm.Parser do
  @moduledoc """
  Parses JSON i18n files into an intermediate representation to be used for
  e.g. printing Elm types and functions.
  """

  alias I18n2Elm.Result
  alias I18n2Elm.Types
  alias I18n2Elm.Types.Translation

  @type reason :: {:invalid_hole_numbering, String.t()}

  @doc ~S"""
  Parses a map of translations of the format:

      %{"Yes" => "Ja",
        "No" => "Nej",
        "Hello" => "Hej, {0}. Leder du efter {1}?"}

  into a corresponding `Translation` struct.
  """
  @spec parse_translation(map, String.t()) :: {:ok, Translation.t()} | {:error, reason()}
  def parse_translation(translation_map, language_tag) do
    translations =
      translation_map
      |> Enum.to_list()
      |> Enum.sort()
      |> Enum.map(&check_for_holes/1)
      |> Enum.map(fn {key, value} -> {"Tid#{key}", value} end)

    with {:ok, _translation_ids} <- Result.traverse(translations, &validate_hole_numbering/1) do
      {:ok, Translation.new(translations, language_tag)}
    end
  end

  # Splitting on `{` and `}` turns "Hej, {0}. Leder..." into the alternating
  # list ["Hej, ", "0", ". Leder...", ...]; text and hole-number strings taking
  # turns. Chunking that two at a time regroups each text run with the hole
  # number immediately following it; the final chunk is a singleton exactly when
  # the value ends in plain text (no trailing hole).
  @spec check_for_holes({String.t(), String.t()}) :: {String.t(), [Types.hole_token()]}
  defp check_for_holes({key, text}) do
    text_with_holes =
      text
      |> split
      |> group
      |> Enum.map(&to_hole_token/1)

    {key, text_with_holes}
  end

  @spec split(String.t()) :: [String.t()]
  defp split(str), do: str |> String.split(~r/\{|\}/)

  @spec group([String.t()]) :: [[String.t()]]
  defp group(lst), do: lst |> Enum.chunk_every(2)

  @spec to_hole_token([String.t()]) :: Types.hole_token()
  defp to_hole_token([text]), do: {:text, text}

  defp to_hole_token([text, hole]) do
    hole_number = hole |> Integer.parse() |> elem(0)
    {:hole, text, hole_number}
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
