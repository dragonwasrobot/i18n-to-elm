defmodule I18n2Elm.Domain.Parser.I18nResource do
  @moduledoc ~S"""
  Represents a parsed i18n resource: a locale plus its list of translation
  key/value pairs.

  JSON representation:

      # da_DK.json
      {
          "Yes": "Ja",
          "No": "Nej",
          "Next": "Næste",
          "Previous": "Forrige",
          "Hello": "Hej, {0}. Leder du efter {1}?"
      }

  Elixir representation:

      %I18nResource{locale: %Locale{language: "da", country: "DK"},
                     translation_pairs: [
                         {"Hello", [{:text, "Hej, "},
                                    {:hole, 0},
                                    {:text, ". Leder du efter "},
                                    {:hole, 1},
                                    {:text, "?"}]},
                         {"Next", [{:text, "Næste"}]},
                         {"No", [{:text, "Nej"}]},
                         {"Previous", [{:text, "Forrige"}]}
                         {"Yes", [{:text, "Ja"}]},
                     ]}
  """

  alias I18n2Elm.Domain.Parser.Locale

  use TypedStruct

  # {Translation key, Translation value}
  @type translation_pair :: {translation_key(), [translation_token()]}

  # The key identifying one translation pair, e.g. "Hello".
  @type translation_key :: String.t()

  # A token is either a segment of plain text or an `{N}`-style hole.
  @type translation_token :: {:text, String.t()} | {:hole, non_neg_integer()}

  typedstruct do
    field :locale, Locale.t(), enforce: true
    field :translation_pairs, [translation_pair()], enforce: true
  end

  @spec new([translation_pair()], Locale.t()) :: t()
  def new(translation_pairs, locale) do
    %__MODULE__{locale: locale, translation_pairs: translation_pairs}
  end

  @doc """
  Whether `i18n_resource` is for the reference locale.
  """
  @spec reference?(t()) :: boolean()
  def reference?(%__MODULE__{locale: locale}) do
    locale == Locale.reference()
  end
end
