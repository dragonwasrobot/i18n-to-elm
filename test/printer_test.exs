defmodule I18n2ElmTest.Printer do
  use ExUnit.Case
  doctest I18n2Elm.Printer, import: true

  alias I18n2Elm.{Printer, Types}
  alias Types.Translation

  test "print language translation file" do
    {translations_file_path, translations_file} =
      %Translation{
        language_tag: "da_DK",
        translations: [
          {"TidHello", [{"Hej, ", 1}, {". Leder du efter ", 0}, {"?"}]},
          {"TidNext", [{"Næste"}]},
          {"TidNo", [{"Nej"}]},
          {"TidPrevious", [{"Forrige"}]},
          {"TidYes", [{"Ja"}]}
        ]
      }
      |> Printer.print_translation("Translations")

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

  test "print ids file" do
    translations = [
      %Translation{
        language_tag: "da_DK",
        translations: [
          {"TidHello", [{"Hej, ", 0}, {". Leder du efter ", 1}, {"?"}]},
          {"TidNext", [{"Næste"}]},
          {"TidNo", [{"Nej"}]},
          {"TidPrevious", [{"Forrige"}]},
          {"TidYes", [{"Ja"}]}
        ]
      },
      %Translation{
        language_tag: "en_US",
        translations: [
          {"TidHello", [{"Hello, ", 0}, {"It is ", 1}, {"you are looking for?"}]},
          {"TidNext", [{"Next"}]},
          {"TidNo", [{"No"}]},
          {"TidPrevious", [{"Previous"}]},
          {"TidYes", [{"Yes"}]}
        ]
      }
    ]

    {ids_file_path, ids_file} = Printer.print_ids(translations, "Translations")

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

  test "prints util file" do
    translations = [
      %Translation{
        language_tag: "da_DK",
        translations: [
          {"TidHello", [{"Hej, ", 0}, {". Leder du efter ", 1}, {"?"}]},
          {"TidNext", [{"Næste"}]},
          {"TidNo", [{"Nej"}]},
          {"TidPrevious", [{"Forrige"}]},
          {"TidYes", [{"Ja"}]}
        ]
      },
      %Translation{
        language_tag: "en_US",
        translations: [
          {"TidHello", [{"Hello, ", 0}, {"It is ", 1}, {"you are looking for?"}]},
          {"TidNext", [{"Next"}]},
          {"TidNo", [{"No"}]},
          {"TidPrevious", [{"Previous"}]},
          {"TidYes", [{"Yes"}]}
        ]
      }
    ]

    {util_file_path, util_file} = Printer.print_util(translations, "Translations")

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
