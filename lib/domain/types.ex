defmodule I18n2Elm.Domain.Types do
  @moduledoc """
  Specifies the main Elixir types used for describing the
  intermediate representations of i18n resources.
  """

  # Format: <language>_<country>, e.g. en_US
  @type language_tag :: String.t()

  # A sequence of plain text, or a text sequence immediately followed by the
  # `{N}`-style placeholder it introduces, turned into a positional Elm function
  # parameter (`hole0`, `hole1`, ...).
  @type hole_token :: {:text, String.t()} | {:hole, String.t(), non_neg_integer()}

  # {Translation key, Translation value}
  @type translation :: {String.t(), [hole_token()]}

  # {Output file path, file content}
  @type printed_file :: {Path.t(), String.t()}

  @doc """
  The language tag treated as the reference/default language.
  """
  @spec reference_language_tag() :: language_tag
  def reference_language_tag, do: "en_US"

  defmodule Translation do
    @moduledoc ~S"""
    Represents a parsed translation file: a language tag plus its list of
    translation key/value pairs.

    JSON:

        # da_DK.json
        {
            "Yes": "Ja",
            "No": "Nej",
            "Next": "Næste",
            "Previous": "Forrige",
            "Hello": "Hej, {0}. Leder du efter {1}?"
        }

    Elixir representation:

        %Translation{language_tag: "da_DK",
                     translations: [
                         {"TidHello", [{:hole, "Hej, ", 0},
                                       {:hole, ". Leder du efter ", 1},
                                       {:text, "?"}]},
                         {"TidNext", [{:text, "Næste"}]},
                         {"TidNo", [{:text, "Nej"}]},
                         {"TidPrevious", [{:text, "Forrige"}]}
                         {"TidYes", [{:text, "Ja"}]},
                     ]}
    """

    alias I18n2Elm.Domain.Types
    use TypedStruct

    typedstruct do
      field :language_tag, Types.language_tag(), enforce: true
      field :translations, [Types.translation()], enforce: true
    end

    @spec new([Types.translation()], Types.language_tag()) :: t()
    def new(translations, language_tag) do
      %__MODULE__{language_tag: language_tag, translations: translations}
    end
  end
end
