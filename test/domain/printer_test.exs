defmodule I18n2ElmTest.Printer do
  use ExUnit.Case, async: true

  alias I18n2Elm.Domain.{Printer, Types}
  alias Types.Translation

  setup do
    translations = %{
      da: %Translation{
        language_tag: "da_DK",
        translations: [
          {"TidHello",
           [{:text, "Hej, "}, {:hole, 1}, {:text, ". Leder du efter "}, {:hole, 0}, {:text, "?"}]},
          {"TidNext", [{:text, "Næste"}]},
          {"TidNo", [{:text, "Nej"}]},
          {"TidPrevious", [{:text, "Forrige"}]},
          {"TidYes", [{:text, "Ja"}]}
        ]
      },
      en: %Translation{
        language_tag: "en_US",
        translations: [
          {"TidHello",
           [
             {:text, "Hello, "},
             {:hole, 1},
             {:text, "It is "},
             {:hole, 0},
             {:text, "you are looking for?"}
           ]},
          {"TidNext", [{:text, "Next"}]},
          {"TidNo", [{:text, "No"}]},
          {"TidPrevious", [{:text, "Previous"}]},
          {"TidYes", [{:text, "Yes"}]}
        ]
      }
    }

    {:ok, translations: translations}
  end

  test "should print a language's Elm translation module", %{translations: translations} do
    # Given a translation (da_DK) with a holed value and several plain ones
    translation = translations.da

    # When generating the corresponding translations module
    {:ok, {translations_file_path, translations_file}} =
      Printer.print_translation(translation, "Translations")

    # Then the file path and generated module match, with hole numbering rather
    # than textual order deciding case parameter order
    expected_translations_file = ~S"""
    module Translations.DaDk exposing (daDkTranslations)

    import Translations.Ids exposing (TranslationId(..))


    daDkTranslations : TranslationId -> String
    daDkTranslations tid =
        case tid of
            TidHello hole0 hole1 ->
                "Hej, " ++ hole1 ++ ". Leder du efter " ++ hole0 ++ "?"

            TidNext ->
                "Næste"

            TidNo ->
                "Nej"

            TidPrevious ->
                "Forrige"

            TidYes ->
                "Ja"
    """

    assert translations_file_path == "./Translations/DaDk.elm"
    assert translations_file == expected_translations_file
  end

  test "should print the shared translation IDs from the reference translation", %{
    translations: translations
  } do
    # Given a reference (en_US) and a non-reference (da_DK) translation
    translations_list = [translations.da, translations.en]

    # When printing the translation IDs module
    {:ok, {ids_file_path, ids_file}} = Printer.print_ids(translations_list, "Translations")

    # Then the file path and generated union type match, derived from reference language
    expected_ids_file = ~S"""
    module Translations.Ids exposing (TranslationId(..))


    type TranslationId
        = TidHello String String
        | TidNext
        | TidNo
        | TidPrevious
        | TidYes
    """

    assert ids_file_path == "./Translations/Ids.elm"
    assert ids_file == expected_ids_file
  end

  test "should reject printing translation IDs when no translation is for the reference language",
       %{translations: translations} do
    # Given only a non-reference (da_DK) translation
    translations_list = [translations.da]

    # When printing the translation IDs module
    result = Printer.print_ids(translations_list, "Translations")

    # Then it fails instead of crashing on the missing reference translation
    assert {:error, :missing_reference_translation} = result
  end

  test "should print the available languages and corresponding dispatch functions", %{
    translations: translations
  } do
    # Given two translations for different languages
    translations_list = [translations.da, translations.en]

    # When printing the util module
    {:ok, {util_file_path, util_file}} = Printer.print_util(translations_list, "Translations")

    # Then the file path and generated Elm module match, listing languages
    # sorted by language tag and dispatching to each one's translation function
    expected_util_file = ~S"""
    module Translations.Util exposing (parseLanguage, translate, Language(..))

    import Translations.Ids exposing (TranslationId)
    import Translations.DaDk exposing (daDkTranslations)
    import Translations.EnUs exposing (enUsTranslations)


    type Language
        = DA_DK
        | EN_US


    parseLanguage : String -> Result String Language
    parseLanguage candidate =
        case candidate of
            "da_DK" ->
                Ok DA_DK

            "en_US" ->
                Ok EN_US

            _ ->
                Err <| "Unknown language: '" ++ candidate ++ "'"


    translate : Language -> TranslationId -> String
    translate language translationId =
        let
            translateFun =
                case language of
                    DA_DK ->
                        daDkTranslations

                    EN_US ->
                        enUsTranslations
        in
            translateFun translationId
    """

    assert util_file_path == "./Translations/Util.elm"
    assert util_file == expected_util_file
  end
end
