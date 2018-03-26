defmodule I18n2Elm.Types do
  @moduledoc ~S"""
  Specifies the main Elixir types used for describing the
  intermediate representations of i18n resources.
  """

  defmodule Translation do
    @moduledoc ~S"""
    Represents a parsed translation file.

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
                         {"TidHello", [{"Hej, ", 0},
                                       {". Leder du efter ", 1},
                                       {"?"}]},
                         {"TidNext", [{"Næste"}]},
                         {"TidNo", [{"Nej"}]},
                         {"TidPrevious", [{"Forrige"}]}
                         {"TidYes", [{"Ja"}]},
                     ]}

    Elm code generated:

    module Translations.DaDk exposing (daDkTranslations)

    import Translations.Ids exposing (TranslationId(..))

    daDkTranslations : TranslationId -> String
    daDkTranslations tid =
        case tid of
            TidHello hole0 hole1 ->
                "Hej, " ++ hole0 ++ ". Leder du efter " ++ hole1 ++ "?"

            TidYes ->
                "Ja"

            TidNo ->
                "Nej"

            TidNext ->
                "Næste"

            TidPrevious ->
                "Forrige"
    """

    @type t :: %__MODULE__{language_tag: String.t(), translations: [{String.t(), String.t()}]}
    defstruct [:language_tag, :translations]

    @spec new(String.t(), [{String.t(), String.t()}]) :: t
    def new(language_tag, translations) do
      %__MODULE__{language_tag: language_tag, translations: translations}
    end
  end

  defmodule LanguageResource do
    @moduledoc ~S"""
    Represents a translation file for a single language.
    """

    @type t :: %__MODULE__{
            module_name: String.t(),
            file_name: String.t(),
            translation_name: String.t(),
            translations: [{String.t(), String.t()}]
          }
    defstruct [:module_name, :file_name, :translation_name, :translations]

    @spec new(String.t(), String.t(), String.t(), [{String.t(), String.t()}]) :: t
    def new(module_name, file_name, translation_name, translations) do
      %__MODULE__{
        module_name: module_name,
        file_name: file_name,
        translation_name: translation_name,
        translations: translations
      }
    end
  end

  defmodule IdsResource do
    @moduledoc ~S"""
    Represents a file containing all translation IDs.
    """

    @type t :: %__MODULE__{module_name: String.t(), ids: [String.t()]}
    defstruct [:module_name, :ids]

    @spec new(String.t(), [String.t()]) :: t
    def new(module_name, ids) do
      %__MODULE__{module_name: module_name, ids: ids}
    end
  end

  defmodule UtilResource do
    @moduledoc ~S"""
    Represents a file util functions for parsing language tags and translation
    IDs into translated values.
    """

    @type t :: %__MODULE__{
            module_name: String.t(),
            imports: [%{file_name: String.t(), translation_name: String.t()}],
            languages: [
              %{string_value: String.t(), type_value: String.t(), translation_fun: String.t()}
            ]
          }
    defstruct [:module_name, :imports, :languages]

    @spec new(String.t(), [map], [map]) :: t
    def new(module_name, imports, languages) do
      %__MODULE__{module_name: module_name, imports: imports, languages: languages}
    end
  end
end
