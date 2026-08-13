defmodule I18n2ElmTest.Printer do
  use ExUnit.Case, async: true

  alias I18n2Elm.Domain.{I18nResource, Locale, Printer}
  alias I18n2Elm.Domain.Parser.{I18nResource, Locale}

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

  test "should print a locale's Elm translation module", %{translations: translations} do
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

    # Then the file path and generated union type match, derived from reference locale
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

  test "should print the i18n-text dispatch module from the reference translation", %{
    translations: translations
  } do
    # Given the reference (en_US) translation
    reference_translation = translations.en

    # When printing the i18n-text module
    {i18n_text_file_path, i18n_text_file} =
      Printer.print_i18n_text_module(reference_translation, "Translations")

    # Then the file path and generated module match, dispatching every
    # TranslationId to an `<i18n-text>` custom element
    expected_i18n_text_file = ~S"""
    module Translations.I18nText exposing (view)

    import Html exposing (Html, node)
    import Html.Attributes exposing (attribute)
    import Json.Encode as Encode
    import Translations.Ids exposing (TranslationId(..))


    view : TranslationId -> Html msg
    view tid =
        let
            values =
                Encode.encode 0 (Encode.list Encode.string (tidToValues tid))
        in
            node "i18n-text"
                [ attribute "tid" (tidToKey tid)
                , attribute "values" values
                ]
                []


    tidToKey : TranslationId -> String
    tidToKey tid =
        case tid of
            TidHello hole0 hole1 ->
                "Hello"

            TidNext ->
                "Next"

            TidNo ->
                "No"

            TidPrevious ->
                "Previous"

            TidYes ->
                "Yes"


    tidToValues : TranslationId -> List String
    tidToValues tid =
        case tid of
            TidHello hole0 hole1 ->
                [ hole0, hole1 ]

            TidNext ->
                []

            TidNo ->
                []

            TidPrevious ->
                []

            TidYes ->
                []
    """

    assert i18n_text_file_path == "./Translations/I18nText.elm"
    assert i18n_text_file == expected_i18n_text_file
  end

  test "should print a locale's runtime JSON asset, reconstructing the {N}-style placeholders",
       %{translations: translations} do
    # Given a translation (da_DK) with a holed value textually out of hole-number order
    translation = translations.da

    # When printing its runtime JSON asset
    {json_file_path, json_file} = Printer.print_locale_json(translation)

    # Then the file path is under the static/ asset root, and hole tokens
    # are rejoined into pretty-printed {N}-style text, in hole-number order
    expected_json_file = ~S"""
    {
      "Hello": "Hej, {1}. Leder du efter {0}?",
      "Next": "Næste",
      "No": "Nej",
      "Previous": "Forrige",
      "Yes": "Ja"
    }
    """

    assert json_file_path == "./static/da_DK.json"
    assert json_file == expected_json_file
  end

  test "should print the locales manifest, sorted regardless of input order", %{
    translations: translations
  } do
    # Given translations passed in reverse locale order (en_US before da_DK)
    translations_list = [translations.en, translations.da]

    # When printing the locales manifest
    {manifest_file_path, manifest_file} = Printer.print_locales_manifest(translations_list)

    # Then the file path is under the static/ asset root, and tags are sorted
    expected_manifest_file = ~S"""
    ["da_DK","en_US"]
    """

    assert manifest_file_path == "./static/locales.json"
    assert manifest_file == expected_manifest_file
  end

  test "should print the web component script, embedded verbatim from disk" do
    # Given the on-disk web component JS source
    source = File.read!("priv/web-component/i18n-text.js")

    # When printing the web component script
    {script_file_path, script_file} = Printer.print_web_component_script()

    # Then the file path is under the static/ asset root, and the content matches
    assert script_file_path == "./static/i18n-text.js"
    assert script_file == source
  end

  test "should print the web-component file set", %{translations: translations} do
    # Given translations for da_DK and en_US locales
    translations_list = [translations.da, translations.en]

    # When printing the web-component file set
    printed_files =
      Printer.print_web_component_modules(translations_list, translations.en, "Translations")

    # Then the file paths cover Ids.elm, I18nText.elm, and the static/ assets
    file_paths =
      printed_files |> Enum.map(fn {file_path, _content} -> file_path end) |> Enum.sort()

    assert file_paths == [
             "./Translations/I18nText.elm",
             "./Translations/Ids.elm",
             "./static/da_DK.json",
             "./static/en_US.json",
             "./static/i18n-text.js",
             "./static/locales.json"
           ]
  end

  test "should print the available locales and corresponding dispatch functions", %{
    translations: translations
  } do
    # Given two translations for different locales
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
