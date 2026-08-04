# i18n to Elm

### Status

Generates Elm types and functions from i18n key/value JSON files.

The tool is meant as an aid if you are using a centralized service to handle the
translation of your i18n resources but then need to import the i18n keys/values
into your Elm application in a type-safe way.

> **Note:** If you like code that generates code, you might like [my other
> project](https://github.com/dragonwasrobot/json-schema-to-elm) which turns
> JSON-schema specs into Elm types + decoders + encoders.

> **Note:** while this repository does contain a `CLAUDE.md` file, tools like
> Claude Code are also used for AI-Assistance and always within a tight feedback
> loop with a human. Code in this repository is never generated in bulk by an
> agent, and never committed without thorough review by a human.

## Setup

This project requires that you already have the appropriate version of
[elixir](http://elixir-lang.org/) and [erlang](https://www.erlang.org/). These
dependencies are managed with [mise](https://mise.jdx.dev/) for this project,
and specified in `mise.local.toml`, but you are free to use whatever method you
use for managing compilers and development tools.

- Clone this repository: `git clone git@github.com:dragonwasrobot/i18n-to-elm.git`
- Build the executable: `MIX_ENV=prod mix build`
- The executable, `i18n2elm`, has now been created in your current working directory.
- Mark the executable as so: `chmod +x i18n2elm`

When working on the codebase, use `fswatch lib test | mix test
--listen-on-stdin` to hot reload the test suite while making changes.

## Usage

Run `./i18n2elm` for usage instructions.

The executable expects one or more JSON files with the naming scheme: `<language
tag>.json`, i.e. `<language>_<COUNTRY>.json`, e.g. `en_US.json` or `da_DK.json`,
and that each JSON file is a simple dictionary of i18n keys and values, for
example:

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

## Vocabulary

Domain terms used throughout the code and documentation, defined once here:

**i18n parsing terms:**
- **I18n resource**: a parsed translation file: a locale plus its list of
  translation key/value pairs.
- **Locale**: the `<language>_<COUNTRY>` identifier a translation file is named
  after, e.g. `da_DK`.
- **Reference locale**: the locale treated as the default locale, currently
  `en_US`. The **I18n resource** matching this locale is what the **Translation
  ID** and the `Util` module's language dispatch are derived from; every input
  file must share its key set, and one input file must be for this language.
- **Translation pair**: one key/value entry within an **I18n resource**'s list;
  a **Translation key** paired with its parsed value, a list of **Translation
  tokens**.
- **Translation key**: the key identifying one translation pair, e.g. `Hello`.
- **Translation token**: one element of a translation value's parsed form;
  either a run of plain text or a **Hole**.
- **Hole**: a `{N}`-style placeholder in a translation value, turned into a
  positional Elm function parameter (`hole0`, `hole1`, ...); numbering must be
  contiguous and 0-indexed.

**Code generation terms:**
- **Translation ID**: both the shared Elm union type of all translation keys,
  and the individual `Tid`-prefixed identifiers that populate it (e.g.
  `TidHello`), derived from the reference translation.
- **Language view**: the printer's per-language template input: a
  translation's file name, translation function name, and translation pairs.
- **IDs view**: the printer's template input for the Translation ID union
  type.
- **Util view**: the printer's template input for the Language union type
  and the `parseLanguage`/`translate` dispatch functions.
- **Module name**: the Elm module name prefix (`--module-name`) under which all
  generated files are namespaced; defaults to `Translations`.

## Example

If we supply `i18n2elm` with the folder `examples/input-i18n-json`, containing
the two JSON files, `da_DK.json`:
``` json
{
    "Hello": "Hej, {0}. Leder du efter {1}?",
    "Next" : "Næste",
    "No": "Nej",
    "Previous": "Forrige",
    "Yes": "Ja"
}

```

and `en_US.json`:
``` json
{
    "Hello": "Hello, {0}. Is it {1} you are looking for?",
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
```

which contains:

- The Danish translations as a function, `daDkTranslations`,
- the English translations as a function, `enUsTranslations`,
- all the translation IDs as a union type, `TranslationId`,
- a union type capturing all available languages, `Language`,
- a function to parse a string into a `Language`, `parseLanguage`, and
- a function to translate a `TranslationId` for a given `Language` into a
  concrete `String` value.
