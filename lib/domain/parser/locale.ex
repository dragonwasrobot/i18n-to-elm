defmodule I18n2Elm.Domain.Parser.Locale do
  @moduledoc ~S"""
  Represents a parsed `<language>_<COUNTRY>` locale identifier, e.g.
  `da_DK` parses to `%Locale{language: "da", country: "DK"}`.
  """

  use TypedStruct

  typedstruct do
    field :language, String.t(), enforce: true
    field :country, String.t(), enforce: true
  end

  @spec new(String.t(), String.t()) :: t()
  def new(language, country) do
    %__MODULE__{language: language, country: country}
  end

  @doc ~S"""
  Parses a raw `<language>_<COUNTRY>` string into a `Locale`, requiring
  exactly two non-empty `_`-separated segments.

  ## Examples

      iex> Locale.parse("da_DK")
      {:ok, %Locale{language: "da", country: "DK"}}

      iex> Locale.parse("danish")
      {:error, {:invalid_locale, "danish"}}

  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, {:invalid_locale, String.t()}}
  def parse(raw_locale) do
    case String.split(raw_locale, "_") do
      [language, country] when language != "" and country != "" ->
        {:ok, new(language, country)}

      _ ->
        {:error, {:invalid_locale, raw_locale}}
    end
  end

  @doc """
  Formats a `Locale` as the string `<language>_<COUNTRY>`.
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{language: language, country: country}), do: "#{language}_#{country}"

  @doc """
  The locale treated as the reference/default language.
  """
  @spec reference() :: t()
  def reference, do: new("en", "US")
end
