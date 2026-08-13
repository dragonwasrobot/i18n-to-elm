# i18n to Elm

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
and specified in `mise.toml`, but you are free to use whatever method you use
for managing compilers and development tools.

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

The following constraints apply, regardless of which output mode is used:

- All input JSON files must contain the exact same set of keys.
- Exactly one input file must be named `en_US.json` - it's used as the
  canonical source for the generated `TranslationId` type (and its hole
  count per key).
- Placeholders within a value (`{0}`, `{1}`, ...) must be numbered
  contiguously starting from `0`.

`i18n2elm` supports two output modes, selected via `--output-mode`:

- `native` (default) - one Elm module per language, each holding an
  exhaustive `case tid of` switch.
- `web-component` - a single dispatch module along with a generated
  `<i18n-text>` custom element and its runtime JSON assets, for
  applications that would rather avoid one generated switch statement per
  language.
  
See the [Example](#example) section below for the exact files the two different
output modes produce.

A complete example of input and output code for both modes can be found in
the `examples` folder.

## Example

### Native output

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

### Web component output

Running `i18n2elm examples/input-i18n-json --output-mode web-component` against
the same `da_DK.json`/`en_US.json` example above produces two directories:
`Translations/`, with `Ids.elm` (identical to the `native` version) and
`I18nText.elm`:

``` elm
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
```

and a sibling `static/` directory with non-Elm resource files:

- `static/locales.json` - the locales manifest, e.g. `["da_DK","en_US"]`, used
  by the web component to resolve a language it doesn't have an exact locale
  JSON asset for (e.g. a browser reporting `en` prefix-matches an available
  `en_*` asset before falling back to `en_US`).
- `static/i18n-text.js` - the `<i18n-text>` web component itself: a small,
  zero-build vanilla JS file (no bundler/TypeScript toolchain required) that
  resolves the page's locale from `document.documentElement.lang` via
  `Intl.Locale`, fetches the matching locale JSON asset, and substitutes
  `{0}`/`{1}`-style placeholders.
- `static/da_DK.json` and `static/en_US.json` - each locale's runtime
  translation dictionary, reconstructed from the parsed input (so these are
  always properly formatted and sorted alphabetically rather than byte-identical
  copies of the original input files).

Note `Util.elm`/`Language`/`parseLanguage`/`translate` are **not** generated in
this mode; the web component resolves the locale itself at runtime, so there's
no `Language` value for an Elm application to construct or pass.

Before using the generated output, the `const BASE_URL = 'CHANGE_ME/'`
placeholder in `static/i18n-text.js` needs to be set to wherever `static/`
actually gets served from relative to the page loading the script. Then load
`i18n-text.js` as a classic (non-module) `<script>` tag, and call
`I18nText.view` from your Elm `view` function:

``` html
<!-- index.html -->
<script src="/translations/static/i18n-text.js"></script>
```

``` elm
-- Main.elm
import Translations.I18nText as I18nText
import Translations.Ids exposing (TranslationId(..))

view : Html msg
view =
    I18nText.view (TidHello "Ada" "the library")
```

A full worked copy of this mode's output is checked in at
`examples/output-web-component/`.

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
- **Output mode**: which file set `i18n2elm` generates, `native` or
  `web-component`, selected via `--output-mode` (defaults to `native`).
- **Translation ID**: both the shared Elm union type of all translation keys,
  and the individual `Tid`-prefixed identifiers that populate it (e.g.
  `TidHello`), derived from the reference translation.
- **Printer view**: the printer's typed EEx template input, one per template
  under `priv/templates/`:
  - **IDs view**: the instance for the Translation ID union type. Used by both
    output modes.
  - **Language view**: the per-language instance: a translation's file name,
    translation function name, and translation pairs (native output only).
  - **Util view**: the instance for the Language union type and the
    `parseLanguage`/`translate` dispatch functions (native output only).
  - **I18n text view**: the instance for `web-component` mode's dispatch module
    (`I18nText.elm`): one clause per `TranslationId`, each pairing a case
    pattern with the raw key it dispatches to and the `List String` values
    expression it passes along (web component output only).
- **Web component**: the generated `<i18n-text>` custom element that
  `web-component` mode's `I18nText.elm` renders, resolving a locale and
  substituting `{0}`/`{1}`-style placeholders entirely at runtime in the
  browser.
- **Static asset root**: the fixed `static/` directory that `web-component`
  mode's non-Elm runtime assets are written into, sibling to the `--module-name`
  directory the Elm files are written into.
- **Locale JSON asset**: one locale's runtime translation dictionary under
  `static/`, reconstructed from that locale's I18n resource.
- **Locales manifest**: `static/locales.json`, the sorted list of locale
  tags the web component uses to resolve a requested language against the
  shipped locale JSON assets.
- **Module name**: the Elm module name prefix (`--module-name`) under which all
  generated files are namespaced; defaults to `Translations`.
