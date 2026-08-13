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
