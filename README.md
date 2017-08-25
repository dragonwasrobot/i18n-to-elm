# i18n to Elm

> Note: This project is very much a work in progress, so use with caution.

> Also: If you like code that generates code, you might
> like [my other project](https://github.com/dragonwasrobot/json-schema-to-elm)
> which turns JSON-schema specs into Elm types+decoders+encoders.

Generates Elm types and functions from i18n key/value JSON files.

The tool is meant as an aid if you are using a centralized service to handle the
translation of your i18n resources but then need to import the i18n keys/values
into your Elm application in a type-safe way.

## Installation

This project requires that you already have [elixir](http://elixir-lang.org/)
and its build tool `mix` installed, this can be done with `brew install elixir`
or similar.

- Clone this repository: `git clone
  git@github.com:dragonwasrobot/i18n-to-elm.git`
- Build an executable: `MIX_ENV=prod mix build`
- An executable, `i18n2elm`, has now been created in your current working
  directory.

## Usage

Run `./i18n2elm` for usage instructions.

The executable expects one or more json files with the naming scheme: `<language
code>_<COUNTRY CODE>.json`, e.g. `en_US.json` or `da_DK.json`, and that each
json file is a simple dictionary of i18n keys and values, for example:

``` json
{
    "Hello": "Hej, {0}. Leder du efter {1}?",
    "Next" : "Næste",
    "No": "Nej",
    "Previous": "Forrige",
    "Yes": "Ja"
}
```

A complete example of input and output code can be found in the `examples`
folder.

## Example

If we supply `i18n2elm` with the folder `examples/input-i18n-json`, containing
the two JSON files, `da_DK.json`:
``` json
{
    "Hello": "Hello, {0}. Is it {1} you are looking for?",
    "Next" : "Næste",
    "No": "Nej",
    "Previous": "Forrige",
    "Yes": "Ja"
}

```

and `en_US.json`:
``` json
{
    "Next" : "Next",
    "No": "No",
    "Previous": "Previous",
    "Yes": "Yes"
}
```

it produces the following Elm files, `Translations/DaDk.elm`:

``` elm
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
```

and `Translations/EnUs.elm`:

``` elm
module Translations.EnUs exposing (enUsTranslations)

import Translations.Ids exposing (TranslationId(..))


enUsTranslations : TranslationId -> String
enUsTranslations tid =
    case tid of
        TidHello hole0 hole1 ->
            "Hello, " ++ hole0 ++ ". Is it " ++ hole1 ++ " you are looking for?"

        TidNext ->
            "Next"

        TidNo ->
            "No"

        TidPrevious ->
            "Previous"

        TidYes ->
            "Yes"
```

and `Translations/Ids.elm`:

``` elm
module Translations.Ids exposing (TranslationId(..))


type TranslationId
    = TidHello String String
    | TidNext
    | TidNo
    | TidPrevious
    | TidYes
```

and finally `Translations/Util.elm`:

``` elm
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
```

which contains:

- The Danish translations as a function, `daDkTranslations`,
- the English translations as a function, `enUsTranslations`,
- all the translation IDs as a union type, `TranslationId`,
- a union type capturing all available languages, `LanguageTag`,
- a function to parse a string into a `LanguageTag`, `parseLanguage`, and
- a function to translate a `TranslationId` for a given `LanguageTag` into a
  concrete `String` value.
