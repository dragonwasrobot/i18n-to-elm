module Translations.DaDk exposing (daDkTranslations)

import Translations.Ids exposing (TranslationId(..))


daDkTranslations : TranslationId -> String
daDkTranslations tid =
    case tid of
        TidHello hole0 hole1 ->
            "Hej, " ++ hole0 ++ ". Leder du efter " ++ hole1 ++ "?"

        TidNext ->
            "Næste"

        TidNo ->
            "Nej"

        TidPrevious ->
            "Forrige"

        TidYes ->
            "Ja"
