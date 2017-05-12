module Translations.Util exposing (parseLanguage, translate, LanguageTag(..))

import Translations.Ids exposing (TranslationId)
import Translations.EnUs exposing (enUsTranslations)
import Translations.DaDk exposing (daDkTranslations)


type LanguageTag
    = EN_US
    | DA_DK


parseLanguage : String -> LanguageTag
parseLanguage tag =
    case tag of
        "en_US" ->
            EN_US

        "da_DK" ->
            DA_DK

        _ ->
            Debug.log
                ("Unknown language: '" ++ tag ++ "', defaulting to English")
                EN_US


translate : LanguageTag -> TranslationId -> String
translate languageTag translationId =
    let
        translateFun =
            case languageTag of
                EN_US ->
                    enUsTranslations

                DA_DK ->
                    daDkTranslations
    in
        translateFun translationId
