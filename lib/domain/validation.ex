defmodule I18n2Elm.Domain.Validation do
  @moduledoc """
  Domain validation rules for a set of translations: a reference-language
  translation must be present, and every translation must share its key set.
  """

  alias I18n2Elm.Domain.Types
  alias I18n2Elm.Domain.Types.Translation

  @type reason :: :missing_reference_translation | {:mismatched_keys, Types.language_tag()}

  @spec validate_reference_language_present([Translation.t()]) ::
          :ok | {:error, :missing_reference_translation}
  def validate_reference_language_present(translations) do
    if Enum.any?(translations, &reference_translation?/1) do
      :ok
    else
      {:error, :missing_reference_translation}
    end
  end

  @spec validate_matching_key_sets([Translation.t()]) ::
          :ok | {:error, {:mismatched_keys, Types.language_tag()}}
  def validate_matching_key_sets(translations) do
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
    |> Enum.map(fn {translation_id, _hole_tokens} -> translation_id end)
    |> MapSet.new()
  end
end
