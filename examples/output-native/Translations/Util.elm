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
