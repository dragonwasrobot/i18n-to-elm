defmodule I18n2Elm.Types do
  @moduledoc """
  Specifies the main Elixir types used for describing the
  intermediate representations of i18n resources.
  """

  # Format: <language>_<country>, e.g. en_US
  @type language_tag :: String.t()

  # {Translation key, Translation value}
  @type translation :: {String.t(), String.t()}

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

    alias I18n2Elm.Types
    use TypedStruct

    typedstruct do
      field :language_tag, Types.language_tag(), enforce: true
      field :translations, [Types.translation()], enforce: true
    end

    @spec new(Types.language_tag(), [Types.translation()]) :: t
    def new(language_tag, translations) do
      %__MODULE__{language_tag: language_tag, translations: translations}
    end
  end

  defmodule LanguageResource do
    @moduledoc """
    Represents a translation file for a single language.
    """

    alias I18n2Elm.Types
    use TypedStruct

    typedstruct do
      field :module_name, String.t(), enforce: true
      field :file_name, String.t(), enforce: true
      field :translation_name, String.t(), enforce: true
      field :translations, [Types.translation()], enforce: true
    end

    @spec new(String.t(), String.t(), String.t(), [Types.translation()]) :: t
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
    @moduledoc """
    Represents a file containing all translation IDs.
    """

    use TypedStruct

    typedstruct do
      field :module_name, String.t(), enforce: true
      field :ids, [String.t()], enforce: true
    end

    @spec new(String.t(), [String.t()]) :: t
    def new(module_name, ids) do
      %__MODULE__{module_name: module_name, ids: ids}
    end
  end

  defmodule UtilResource do
    @moduledoc """
    Represents a file util functions for parsing language tags and translation
    IDs into translated values.
    """

    use TypedStruct

    @type import :: %{file_name: String.t(), translation_name: String.t()}
    @type language :: %{
            string_value: String.t(),
            type_value: String.t(),
            translation_fun: String.t()
          }

    typedstruct do
      field :module_name, String.t(), enforce: true
      field :imports, [import], enforce: true
      field :languages, [language], enforce: true
    end

    @spec new(String.t(), [import], [language]) :: t
    def new(module_name, imports, languages) do
      %__MODULE__{module_name: module_name, imports: imports, languages: languages}
    end
  end
end
