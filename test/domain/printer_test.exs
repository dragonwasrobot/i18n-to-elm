defmodule I18n2ElmTest.Printer do
  use ExUnit.Case, async: true

  alias I18n2Elm.Domain.{I18nResource, Locale, Printer}

  setup do
    translations = %{
      da: %I18nResource{
        locale: %Locale{language: "da", country: "DK"},
        translation_pairs: [
          {"Hello",
           [{:text, "Hej, "}, {:hole, 1}, {:text, ". Leder du efter "}, {:hole, 0}, {:text, "?"}]},
          {"Next", [{:text, "Næste"}]},
          {"No", [{:text, "Nej"}]},
          {"Previous", [{:text, "Forrige"}]},
          {"Yes", [{:text, "Ja"}]}
        ]
      },
      en: %I18nResource{
        locale: %Locale{language: "en", country: "US"},
        translation_pairs: [
          {"Hello",
           [
             {:text, "Hello, "},
             {:hole, 1},
             {:text, "It is "},
             {:hole, 0},
             {:text, "you are looking for?"}
           ]},
          {"Next", [{:text, "Next"}]},
          {"No", [{:text, "No"}]},
          {"Previous", [{:text, "Previous"}]},
          {"Yes", [{:text, "Yes"}]}
        ]
      }
    }

    {:ok, translations: translations}
  end

  test "should print a language's Elm translation module", %{translations: translations} do
    # Given a translation (da_DK) with a holed value and several plain ones
    translation = translations.da

    # When generating the corresponding translations module
    {translations_file_path, translations_file} =
      Printer.print_translation_module(translation, "Translations")

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
    # Given the reference (en_US) translation
    reference_translation = translations.en

    # When printing the translation IDs module
    {ids_file_path, ids_file} = Printer.print_ids_module(reference_translation, "Translations")

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

  test "should reject printing translations when no translation is for the reference language",
       %{translations: translations} do
    # Given only a non-reference (da_DK) translation
    translations_list = [translations.da]

    # When printing all translation modules
    result = Printer.print_elm_i18n_modules(translations_list, "Translations")

    # Then it fails instead of crashing on the missing reference translation
    assert {:error, :missing_reference_translation} = result
  end

  test "should print the available languages and corresponding dispatch functions", %{
    translations: translations
  } do
    # Given two translations for different languages
    translations_list = [translations.da, translations.en]

    # When printing the util module
    {util_file_path, util_file} = Printer.print_util_module(translations_list, "Translations")

    # Then the file path and generated Elm module match, listing languages
    # sorted by locale and dispatching to each one's translation function
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
