// Unit tests for the pure, DOM-free helpers in ../i18n-text.js.
//
// Run with: node --test priv/web-component/test/i18n-text.test.js
//
// Deliberately uses only Node's built-in test runner/assert (no
// package.json, no bundler) — see README.md for why this repo doesn't add a
// full JS testing toolchain for a single small file.

const test = require('node:test');
const assert = require('node:assert/strict');

const { normalizeLocale, resolveLocale, substitute } = require('../i18n-text.js');

// ** normalizeLocale

test('should convert a hyphenated BCP47 tag to the underscore locale convention', () => {
  // Given two hyphenated BCP47 language tags
  const enUs = 'en-US';
  const daDk = 'da-DK';

  // When normalizing them
  const normalizedEnUs = normalizeLocale(enUs);
  const normalizedDaDk = normalizeLocale(daDk);

  // Then they conform to the underscore-separated locale-tag convention
  assert.equal(normalizedEnUs, 'en_US');
  assert.equal(normalizedDaDk, 'da_DK');
});

test('should pass a language-only tag through unchanged', () => {
  // Given a BCP47 tag with no region subtag
  const languageOnly = 'en';

  // When normalizing it
  const normalized = normalizeLocale(languageOnly);

  // Then it passes through unchanged
  assert.equal(normalized, 'en');
});

test('should ignore script/extension subtags rather than misreading them as the region', () => {
  // Given BCP47 tags carrying a script subtag and a Unicode extension subtag
  const scriptTag = 'zh-Hans-CN';
  const extensionTag = 'en-US-u-ca-buddhist';

  // When normalizing them
  const normalizedScriptTag = normalizeLocale(scriptTag);
  const normalizedExtensionTag = normalizeLocale(extensionTag);

  // Then only the language and region subtags are kept
  assert.equal(normalizedScriptTag, 'zh_CN');
  assert.equal(normalizedExtensionTag, 'en_US');
});

test('should return undefined for empty, blank, or undefined input', () => {
  // Given empty, whitespace-only, and undefined input
  const empty = '';
  const blank = '   ';
  const missing = undefined;

  // When normalizing them
  const normalizedEmpty = normalizeLocale(empty);
  const normalizedBlank = normalizeLocale(blank);
  const normalizedMissing = normalizeLocale(missing);

  // Then none of them resolve to a locale tag
  assert.equal(normalizedEmpty, undefined);
  assert.equal(normalizedBlank, undefined);
  assert.equal(normalizedMissing, undefined);
});

test('should fall back to naive hyphen-to-underscore normalization for a tag Intl.Locale rejects', () => {
  // Given a tag whose region subtag ("USA") is not valid 2-alpha/3-digit,
  // so Intl.Locale throws
  const invalidRegion = 'en-USA';

  // When normalizing it
  const normalized = normalizeLocale(invalidRegion);

  // Then it falls back to a plain hyphen-to-underscore replacement
  assert.equal(normalized, 'en_USA');
});

// ** resolveLocale

test('should return an exact match when present in the available tags', () => {
  // Given a desired tag that is itself present in the manifest
  const desired = 'da_DK';
  const available = ['da_DK', 'en_US'];

  // When resolving it
  const resolved = resolveLocale(desired, available);

  // Then the exact match is returned
  assert.equal(resolved, 'da_DK');
});

test('should prefix-match a language-only tag against an available region variant', () => {
  // Given a language-only desired tag with two same-language candidates,
  // listed out of sorted order
  const desired = 'en';
  const available = ['en_US', 'en_GB'];

  // When resolving it
  const resolved = resolveLocale(desired, available);

  // Then the sorted-first same-language candidate is returned
  assert.equal(resolved, 'en_GB');
});

test('should fall back to en_US when nothing matches', () => {
  // Given a desired tag with no same-language candidate available
  const desired = 'fr_FR';
  const available = ['da_DK', 'en_US'];

  // When resolving it
  const resolved = resolveLocale(desired, available);

  // Then it falls back to en_US
  assert.equal(resolved, 'en_US');
});

// ** substitute

test('should splice positional values into {0}/{1} placeholders', () => {
  // Given a template with two placeholders and matching values
  const template = 'Hej, {0}. Leder du efter {1}?';
  const values = ['Peter', 'mig'];

  // When substituting
  const result = substitute(template, values);

  // Then each placeholder is replaced by its positional value
  assert.equal(result, 'Hej, Peter. Leder du efter mig?');
});

test('should leave text with no placeholders untouched', () => {
  // Given a template with no {N}-style placeholders
  const template = 'Ja';

  // When substituting against it with no values
  const result = substitute(template, []);

  // Then the text is returned unchanged
  assert.equal(result, 'Ja');
});

test('should substitute an empty string for a missing value', () => {
  // Given a template with a placeholder but no matching value
  const template = 'Hello, {0}';

  // When substituting against it with no values
  const result = substitute(template, []);

  // Then the placeholder is replaced with an empty string
  assert.equal(result, 'Hello, ');
});
