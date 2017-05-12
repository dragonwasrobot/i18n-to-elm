module Translations.EnUs exposing (enUsTranslations)

import Translations.Ids exposing (TranslationId(..))


enUsTranslations : TranslationId -> String
enUsTranslations tid =
    case tid of
        TidNext ->
            "Next"

        TidNo ->
            "No"

        TidPrevious ->
            "Previous"

        TidYes ->
            "Yes"
