module Translations.Util exposing (parseLanguage, translate, LanguageTag(..))

import Translations.Ids exposing (TranslationId)
import Translations.DaDk exposing (daDkTranslations)
import Translations.EnUs exposing (enUsTranslations)


type LanguageTag
    = DA_DK
    | EN_US


parseLanguage : String -> LanguageTag
parseLanguage tag =
    case tag of
        "da_DK" ->
            DA_DK

        "en_US" ->
            EN_US

        _ ->
            Debug.log
                ("Unknown language: '" ++ tag ++ "', defaulting to English")
                EN_US


translate : LanguageTag -> TranslationId -> String
translate languageTag translationId =
    let
        translateFun =
            case languageTag of
                DA_DK ->
                    daDkTranslations

                EN_US ->
                    enUsTranslations
    in
        translateFun translationId
