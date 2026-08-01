# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An Elixir escript CLI (`i18n2elm`) that converts a folder of i18n key/value
JSON files into a set of Elm modules (types, per-language translation
functions, and a language-dispatch util module). See README.md for
input/output examples.

## Commands

- `mix deps.get` — install dependencies
- `mix build` — alias for `deps.get, compile, escript.build`; produces the
  `i18n2elm` executable in the project root (run with `MIX_ENV=prod mix build`
  for a release build)
- `mix test` — run the full test suite (ExUnit)
- `mix test test/parser_test.exs` — run a single test file
- `mix test test/parser_test.exs:36` — run a single test at a given line
- `mix test --cover` — run tests with coverage (via ExCoveralls, configured as
  the `test_coverage` tool in `mix.exs`)
- `mix credo --strict` — static analysis/linting (config: `~> 1.7`, dev/test
  only); no `.credo.exs` is checked in, so this runs Credo's full default
  check list — `--strict` widens which of those get *reported* versus the
  bare `mix credo`'s priority-filtered output, so always use `--strict`
- `mix dialyzer` — type checking via Dialyxir
- `mix format` — format `mix.exs`, `config/**`, `lib/**`, `test/**` per
  `.formatter.exs`
- `mix docs` — generate ExDoc documentation
- `./scripts/smoke_test.sh` — manual-handoff smoke test for `I18n2Elm.main/1`'s
  CLI wiring: builds the escript and exercises it end-to-end (golden path,
  help text, unknown flag, no files found, malformed JSON, missing reference
  language file, read-only output dir), asserting on real exit codes — the
  one class of check `mix test` structurally can't cover, since `main/1`
  calls `exit/1` directly. Local-only, not wired into CI.
- CI (`.github/workflows/elixir.yml`) runs `mix deps.get` then `mix test` on
  every push/PR to `master`, using the Elixir/Erlang versions pinned in
  `mise.local.toml`

## Architecture

The pipeline is a straight-line 3-stage transform, each stage in its own
module under `lib/`:

1. **`I18n2Elm` (`lib/i18n2elm.ex`)** — CLI entry point (`main/1`). Parses
   args with `OptionParser` (only recognized flag: `--module-name`, default
   `"Translations"`), resolves the input path(s) to a flat list of `.json`
   files (recursing into directories), creates the output directory, then
   calls `generate/2`, which reads and JSON-decodes each file itself
   (`read_translation_file/1`, Jason) before wiring `Parser` → `Printer` →
   file writes — the only place file I/O happens, keeping `Parser` and
   `Printer` pure.

2. **`I18n2Elm.Parser` (`lib/parser.ex`)** — Pure: turns an already-decoded
   JSON map plus a `language_tag` into a `%Translation{language_tag,
   translations}` struct (`parse_translation/2`); it does no file I/O
   itself — the caller derives `language_tag` from the file's basename
   (minus `.json`), e.g. `da_DK.json` → `"da_DK"`. Each JSON key is
   prefixed `Tid` (e.g. `"Hello"` → `"TidHello"`). Translation *values* are
   scanned for `{N}`-style placeholders (`check_for_holes/1`) and turned
   into a list of tagged tuples: `{:text, text}` for plain text runs,
   `{:hole, text, hole_number}` for text immediately followed by a
   placeholder — this list is the intermediate representation consumed by
   the printer.

3. **`I18n2Elm.Printer` (`lib/printer.ex`)** — Turns `Translation` structs
   into `{file_path, file_content}` pairs using EEx templates loaded from
   `priv/templates/` (`language.elm.eex`, `ids.elm.eex`, `util.elm.eex`; the
   templates directory is configured via `config :i18n2elm,
   templates_location:` in `config/config.exs`). Produces, per invocation:
   - one `<Lang><Country>.elm` file per input language (e.g. `DaDk.elm`)
     exposing a `<lang><Country>Translations : TranslationId -> String`
     function (`print_translation/2`)
   - one `Ids.elm` file with the shared `TranslationId` union type, derived
     from the **reference translation** — **all input JSON files must share
     identical key sets, and one of them must be for the reference language**
     (`Types.reference_language_tag/0`, currently `en_US`); `generate/2`
     validates this language is present before printing anything
     (`validate_reference_language_present/1`), so `print_ids/2` and
     `print_util/2` can assume it by construction
   - one `Util.elm` file with a `Language` union type, `parseLanguage`, and a
     `translate` dispatcher across all languages (`print_util/2`)

4. **`I18n2Elm.Result` (`lib/result.ex`)** — `traverse/2`, a small shared
   helper for composing functions that return `{:ok, _} | {:error, _}`:
   applies a fallible function across a list, collecting every `:ok` value
   in order, or stopping at the first `:error`. Used across `I18n2Elm` and
   `Printer` wherever a list of files/translations must all succeed
   together (e.g. reading every input file, writing every output file).

5. **`I18n2Elm.Types` (`lib/types.ex`)** — Defines `Translation` (via
   `TypedStruct`), the parser's output struct. The printer's template inputs
   (language resource, IDs resource, util resource) are passed as plain maps
   and lists rather than dedicated structs.

Data flows one direction only: JSON → `Translation` structs (Parser) →
`{file_path, content}` pairs (Printer) → disk (`I18n2Elm.generate/2`). There
is no Elm-side code in this repo; `examples/` holds a worked
input-JSON/output-Elm pair used as a manual reference (mirrored in the
README), not fixtures consumed by tests.

Elm identifier/file naming (e.g. `da_DK` → module `DaDk`, function
`daDkTranslations`, type constructor `DA_DK`) is derived purely from the
`language_tag` string split on `_`, in `Printer.create_file_name/1` and
`Printer.create_translation_name/1` — the "hole" numbering in translation
text must be contiguous and 0-indexed since it maps directly to Elm function
parameters (`hole0`, `hole1`, ...).

## Guiding principles

These shape how code in this repo is written. They apply to every change.

- **Readability is the most important property.** Optimize for the next
  reader. A clever one-liner that costs five minutes of head-scratching loses
  to the boring version.
- **Let code breathe.** Surround multi-line `if`/`case`/`cond`/`with` blocks
  and multi-line pipelines with a blank line above and below, unless they sit
  immediately under an enclosing `do`/`def` or a comment introducing them.

  ```elixir
  # ❌ dense — blocks have no breathing room mid-function
  translation = Enum.find(translations, &(&1.language_tag == "en_US"))
  if is_nil(translation) do
    raise "missing en_US"
  end
  ids = translation.translations |> Enum.map(&elem(&1, 0))
  if ids == [] do
    []
  end

  # ✅ blank lines frame each block
  translation = Enum.find(translations, &(&1.language_tag == "en_US"))

  if is_nil(translation) do
    raise "missing en_US"
  end

  ids = translation.translations |> Enum.map(&elem(&1, 0))

  if ids == [] do
    []
  end
  ```
- **Declaration order is top-down.** If function A depends on function B,
  declare A above B — same for private helpers. See
  `Printer.print_translation/2` (`lib/printer.ex:46`), declared before the
  private helpers it calls (`create_translation_pair/1`, `lib/printer.ex:72`).
- **Order parameters by relevance.** The value a function is fundamentally
  about leads; contextual criteria follow. `print_translation(translation,
  module_name)` (`lib/printer.ex:46`) leads with its subject and trails with
  the injected naming context — mirror this order in new functions.
- **Comments earn their place.** `@doc` on public functions describes *what*
  they do and *why* a caller would reach for them — not *how*; the body (and
  any doctest) shows the how. A negation ("does X, not Y") earns its place
  only when Y is an expectation the reader could form from something visible
  — a sibling function, a stdlib default, an adjacent type — not a discarded
  design idea that only lived in a past conversation; the reader can't see
  the ghost being refuted, so cut it.
- **Every module opens with a `@moduledoc` naming its concern.** One to three
  sentences is the norm (`lib/parser.ex:2-5`, `lib/printer.ex:2-5`); expand to
  a longer doc with examples only when the module has non-obvious usage, the
  way `lib/i18n2elm.ex:2-16` documents CLI invocation. Writing the one-concern
  sentence doubles as a cohesion test — if it's hard to write, the module is
  doing too much.
- **Every function gets a `@spec`, public or private.** See `lib/printer.ex`,
  where specs exist even on private helpers like `create_file_path/2`
  (`lib/printer.ex:174`). Add `@doc` on top where the behavior needs
  explaining or a doctest helps (`lib/parser.ex:25-47`); a simple
  pass-through function needs neither.
- **Prefer short functions.** ~50 LOC is the soft ceiling. Treat approaching
  it as a signal the function is doing several things — extract named helpers
  before adding more.
- **Functional core, imperative shell.** `Printer` is the pure core — pure
  transforms with no side effects; `I18n2Elm` (`lib/i18n2elm.ex`) is the
  imperative shell, the only place file I/O belongs, and the boundary where
  new cross-cutting logic goes — never smuggled into a module meant to stay
  pure. `Logger` is the one exception to "no side effects in the core": it's
  a cross-cutting singleton, callable directly via `require Logger` from any
  module without threading it through function signatures or counting
  against that module's purity.
- **Keep one ubiquitous language across code and docs.** Every domain concept
  has exactly one name, used identically in specs, moduledocs, tests, and the
  README — the registry is the README's `§Vocabulary` section. Before naming
  something new, check it; coining a genuinely new domain term means adding
  it to the registry in the same change.
- **No stringly-typed values for finite variants; branch exhaustively.**
  Prefer atoms or tagged tuples over bare strings when a value has a fixed
  set of variants, and branch on them with `case`/multiple function heads
  rather than `if`/`else` chains.
- **Name your conditionals.** Two forms: extract a complex boolean
  expression (e.g. `a and b or (c and not d)`) into a named local variable
  before branching on it; extract a complex predicate into a named local
  function. See `Printer.hole?/1` (`lib/printer.ex:99-100`) for the
  latter — a one-line predicate function used from `Enum.filter/2` instead
  of an inline pattern-match expression.
- **Always use multi-line `if/do/else/end`.** Never the `if cond, do: x, else:
  y` keyword-list form for anything beyond a trivial single expression — it
  keeps conditionals easy to extend and diff.
- **Destructure instead of repeating a path.** When a struct field is
  accessed more than twice in a function, destructure it in the function
  head rather than repeating `thing.field`. See `create_file_name/1` and
  `create_translation_name/1` (`lib/printer.ex:184`, `:190`):
  `def create_file_name(%Translation{language_tag: language_tag})` instead of
  reaching into `translation.language_tag` repeatedly.
- **Validate only at boundaries.** Trust internal callers. Validate at I/O
  edges — `I18n2Elm.main/1`'s argument validation (`lib/i18n2elm.ex:27-43`)
  is the existing example; don't re-check an input already validated at a
  boundary deeper in the call chain.
- **Don't abstract until the second use.** Three similar lines is better than
  a premature abstraction. Delete duplication when it appears the second
  time, not in anticipation.
- **Make impossible states unrepresentable.** Model data with tagged
  unions/tuples and mandatory (`enforce: true`) struct fields, so a state
  that can't actually occur can't be constructed — rather than an optional
  field or loose type that admits combinations the rest of the code (and its
  tests) then has to defend against.
- **Return `{:ok, value} | {:error, reason}` for expected failures; `raise`
  only for the unrecoverable.**
  - Functions with an expected failure mode (a bad file path, malformed
    JSON, mismatched translation key sets across language files) return
    `{:ok, value} | {:error, reason}`, chained with `with`.
  - Wrap each throwing call at the point it can raise, in a small helper
    that returns `{:ok, _} | {:error, _}` — don't wrap a whole function body
    in a broad `rescue`.
  - `raise`/bang-calls stay reserved for genuinely unrecoverable or
    programmer-error conditions.
  - `I18n2Elm.main/1` is the dispatcher: it unwraps the top-level `with`
    chain and, on `{:error, reason}`, prints a message and calls `exit/1` —
    extending the pattern already used for CLI-argument errors
    (`lib/i18n2elm.ex:27-43`) to file/parse errors too.

## Feature workflow

New functionality is developed test-first, following a TDD cycle (**Red →
Green → Blue**). Both the tests and the implementation can be written by
Claude, but they must move through the cycle in order — never write
production code without a failing test motivating it. The developer stays in
the loop on each iteration; keep cycles tight.

The cycle for each behavior:

1. Enumerate the behaviors to implement — a numbered list — and surface
   clarifying questions before writing any code.
2. If a new module is needed, create it with a typed stub — `@moduledoc`,
   correct `@spec`s, bodies that `raise "not implemented"`. No logic yet.
3. Write **exactly one** `test` block for the next behavior (labeled, e.g.
   "behavior 2/5") — following §Testing conventions — and confirm it fails
   (**Red**). The failure must be a test/assertion failure or the stub's
   `not implemented` raise — not a compile warning or missing-module error.
4. Implement **only** what this specific test requires (**Green**). Do not
   write logic that no currently-failing test exercises — that belongs to a
   future cycle. A sign the Green was too broad: the next test you write
   passes immediately without code changes.
5. Review the diff against the **Guiding principles** (**Blue**) — a
   judgment review, not a tool run. Common targets: missing `@spec`,
   functions approaching the ~50 LOC ceiling, missing named conditionals,
   declaration order, whitespace. Refactor before moving on.
6. **Verification** — run `mix dialyzer`, `mix credo --strict`, `mix format
   --check-formatted`, and `mix test` before moving on. A green suite
   confirms the mechanics, not the Blue review; the two are distinct steps.
7. **Stop and hand the diff back.** End the turn so the developer reads the
   cycle's diff before the next one starts. Never begin the next test in the
   same response.
8. Repeat from step 3 until all behaviors are covered.

**Forbidden:**

- Writing production code before a test fails for it.
- Writing more than one `test` block before running the test suite.
- Implementing logic that no currently-failing test requires.
- Deleting or skipping existing tests to make a change land.
- Marking work as "tests later".
- Starting the next cycle's test before the developer has reviewed the
  current one's diff.

**When unit tests aren't possible** (CLI arg wiring in `I18n2Elm.main/1`, the
EEx templates under `priv/templates/`): skip the Red → Green cycle, but
replace it with a handoff — describe the golden path and any relevant edge
cases for the developer to exercise manually, and do not mark the work done
until they confirm. `mix dialyzer`/`mix credo --strict` still run.

## Refactor workflow

Refactoring spans multiple files or principles and doesn't fit the
single-test-per-cycle TDD loop. The discipline is different but the goal is
the same: keep cycles tight and keep the developer in the loop.

The cycle for a structured refactor:

1. Enumerate the changes up front — a numbered list of violations, files, or
   principles in scope. Surface it before touching any code.
2. Apply **one** labeled change — its own tool call with a short label (e.g.
   "change 3/4", "finding #2") so it's reviewable in isolation.
3. Review that change against the **Guiding principles** — the same check as
   the feature loop's Blue step, watching especially for violations the
   refactor itself introduced.
4. **Stop and hand the diff back.** End the turn so the developer reads the
   change before the next lands — that human read is the second review. A
   labeled change may span more than one edit; finish it, then yield. Never
   begin the next labeled change in the same response.
5. Verify after each logical batch with `mix dialyzer`, `mix credo --strict`,
   `mix format --check-formatted`, and `mix test`.

**Forbidden:**

- Beginning the next labeled change before the developer has reviewed the
  previous one — finish a change, then yield the turn.
- Batching unrelated edits into a single tool call.
- Applying a fix that touches multiple principles in a single change.
- Continuing past a `mix dialyzer`/`mix credo --strict`/`mix format`/`mix
  test` failure without surfacing it.

**When automated verification isn't possible** (CLI wiring, EEx templates):
replace the verify step with a handoff — describe the golden path and any
relevant edge cases for the developer to exercise manually.

## Testing conventions

**Test format.** Test names start with "should" and state the behavior; use
BDD-style Given/When/Then comments inside new or changed `test` blocks:

```elixir
test "should parse a translation value with two holes" do
  # Given a translation value with two {N}-style placeholders
  json = ~S"""
  {"Hello": "Hej, {0}. Leder du efter {1}?"}
  """

  # When parsing it for the da_DK language tag
  parsed = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

  # Then the value is split into tagged text/hole tuples in order
  assert parsed == %Translation{
           language_tag: "da_DK",
           translations: [
             {"TidHello", [{:hole, "Hej, ", 0}, {:hole, ". Leder du efter ", 1}, {:text, "?"}]}
           ]
         }
end
```

`doctest` examples inside `@doc` blocks (`lib/parser.ex:25-47`) document
behavior as plain input/output pairs and don't take Given/When/Then
comments.

**Assertion shape.** Assert on whole-struct equality (`assert parsed ==
expected`, as in `test/parser_test.exs:33`). For the `{:ok, _} | {:error, _}`
convention, unwrap by pattern-matching — `assert {:ok, value} = result` then
assert on `value`, or `assert {:error, reason} = result` then assert on
`reason`.

**Orchestrator/integration coverage.** Cover `I18n2Elm.generate/2` (the
orchestrator) via `test/e2e_test.exs`, against real temporary directories
rather than mocked adapters.

**What to test.**

- **Test the unit's own contribution, not its dependencies.** A function
  that delegates to a well-tested helper needs at most one test for what
  *it* adds.
- **Changing a contract means editing the test that owns it, not appending
  a new one.** When a function's behavior changes, find the existing `test`
  block that pins the old contract and update it in place. The tell is
  duplicated setup — if the new test would re-stage the same fixture and
  assert on the same field as an existing one, it belongs *in* that existing
  test.
- **Spec language.** Test names and Given/When/Then comments describe
  behavior in domain terms, not implementation — don't reference argument
  names or function calls in the description itself.

**Forbidden:**

- Adding a parallel `test` block for changed behavior — edit the test that
  owns the contract.
- Re-testing a dependency's edge cases through a thin wrapper that delegates
  to it.

## Logging conventions

- **`Logger` (via `require Logger`) is for diagnostics; `IO.puts` is for
  CLI-user-facing text; `IO.binwrite` is for writing generated file
  contents.** See the split in `lib/i18n2elm.ex` and keep new code on the
  same sides of that line.
- **Level assignment:** `debug` for argument/file-list/output dumps
  (`lib/i18n2elm.ex:24,38,62`); `info` for milestones ("Created file: ...",
  `lib/i18n2elm.ex:126`); `warning` for an anomaly the run survives, e.g. a
  non-`.json` file encountered while walking an input directory (logged and
  skipped by `expand_path/1`, `lib/i18n2elm.ex:80-95`); `error` logged once
  at the dispatcher (`main/1`'s `with`/`else`, `lib/i18n2elm.ex:40-52`)
  immediately before `exit` — a malformed or unreadable input file is a hard
  stop under the `{:ok, _} | {:error, _}` convention, not a per-file skip,
  since every input file must share identical keys for the output to be
  valid.
- **Message shape:**

  ```elixir
  Logger.debug("Arguments: #{inspect(args)}")
  Logger.info("Created file: #{file_path}")
  ```
