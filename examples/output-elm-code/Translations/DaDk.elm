module Translations.DaDk exposing (daDkTranslations)

import Translations.Ids exposing (TranslationId(..))


daDkTranslations : TranslationId -> String
daDkTranslations tid =
    case tid of
        TidNext ->
            "Næste"

        TidNo ->
            "Nej"

        TidPrevious ->
            "Forrige"

        TidYes ->
            "Ja"
