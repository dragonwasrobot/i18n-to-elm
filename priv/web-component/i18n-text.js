// Usage: <i18n-text tid="Hello" values='["Foo","Bar"]'></i18n-text>
//
// Resolves the page's locale from `document.documentElement.lang`, fetches the
// matching `<locale>.json` resource file, and substitutes `{0}`, `{1}`, ...
// placeholders with the values passed via the `values` attribute.

(function () {
  'use strict';

  const FALLBACK_LOCALE = 'en_US';

  // NOTE: Update this to point at wherever this file's sibling static/ assets
  // (the per-locale JSON files and locales.json) are actually served from
  // in your deployment.
  const BASE_URL = 'CHANGE_ME/';

  // Parses a BCP47 tag (e.g. from `document.documentElement.lang`) and
  // returns a normalized string representation of the locale, and `undefined`
  // for all empty values.
  function normalizeLocale(bcp47) {
    if (!bcp47 || !bcp47.trim()) {
      return undefined;
    }

    try {
      const locale = new Intl.Locale(bcp47.trim());
      return locale.region ? `${locale.language}_${locale.region}` : locale.language;
    } catch (err) {
      console.warn(`Failed to parse ${bcp47} as a valid locale with error ${err}`);
      return bcp47.trim().replace(/-/g, '_');
    }
  }

  function resolveLocale(desiredTag, availableTags) {
    const primarySubtag = (localeTag) => localeTag ? localeTag.split('_')[0] : undefined;

    if (availableTags.includes(desiredTag)) {
      return desiredTag;
    }

    const desiredPrimary = primarySubtag(desiredTag);
    const candidates = availableTags
      .filter((tag) => primarySubtag(tag) === desiredPrimary)
      .sort();

    return candidates.length > 0 ? candidates[0] : FALLBACK_LOCALE;
  }

  function substitute(template, values) {
    return template.replace(/\{(\d+)\}/g, (match, holeIndex) => {
      const value = values[Number(holeIndex)];

      if (value === undefined) {
        console.warn(`i18n-text: missing value for hole {${holeIndex}} in "${template}"`);
        return '';
      }

      return value;
    });
  }

  // NOTE: Purely for testing purposes
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { normalizeLocale, resolveLocale, substitute };
  }

  // NOTE: Everything below registers the actual custom element and only makes
  // sense in a browser.
  if (typeof window === 'undefined' || typeof customElements === 'undefined') {
    return;
  }

  // Each cache stores promises (not resolved values) so concurrent renders
  // in the same tick share one in-flight fetch instead of racing duplicates.
  let manifestPromise = undefined;
  const dictCache = new Map();

  function fetchJson(url) {
    return fetch(url).then((res) => {
      if (!res.ok) {
        throw new Error(`HTTP ${res.status} for ${url}`);
      }
      return res.json();
    });
  }

  function getManifest() {
    if (!manifestPromise) {
      manifestPromise = fetchJson(new URL('locales.json', BASE_URL)).catch((err) => {
        console.warn(`i18n-text: could not load locales.json (${err.message})`);
        return [];
      });
    }

    return manifestPromise;
  }

  function fetchDict(locale) {
    if (dictCache.has(locale)) {
      return dictCache.get(locale);
    }

    const promise = fetchJson(new URL(`${locale}.json`, BASE_URL)).catch((err) => {
      if (locale === FALLBACK_LOCALE) {
        throw err;
      }

      console.warn(
        `i18n-text: locale "${locale}" unavailable (${err.message}), falling back to ${FALLBACK_LOCALE}`
      );

      return fetchDict(FALLBACK_LOCALE);
    });

    dictCache.set(locale, promise);
    return promise;
  }

  // All currently-connected instances, so a page-level language change (see
  // langObserver below) can refresh every mounted element even when an
  // individual element's own tid/values attributes haven't changed - Elm's
  // virtual DOM only patches a node's attributes when they actually differ,
  // so a language switch that doesn't happen to change any tid/values would
  // otherwise leave stale text on screen.
  const instances = new Set();

  const langObserver = new MutationObserver(() => {
    instances.forEach((instance) => instance._render());
  });
  langObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['lang'] });

  class I18nTextElement extends HTMLElement {
    static get observedAttributes() {
      return ['tid', 'values'];
    }

    // Guards against a stale async fetch response overwriting a newer
    // render (see _render below).
    _renderToken = 0;

    connectedCallback() {
      instances.add(this);
      this._render();
    }

    disconnectedCallback() {
      instances.delete(this);
    }

    attributeChangedCallback(name, oldVal, newVal) {
      if (oldVal !== newVal && this.isConnected) {
        this._render();
      }
    }

    _render() {
      const tid = this.getAttribute('tid');

      if (!tid) {
        return;
      }

      const token = ++this._renderToken;

      let values = [];
      const rawValues = this.getAttribute('values');

      if (rawValues) {
        try {
          values = JSON.parse(rawValues);
        } catch (err) {
          console.error(`i18n-text: invalid values attribute "${rawValues}"`);
        }
      }

      const desired = normalizeLocale(document.documentElement.lang) || FALLBACK_LOCALE;

      getManifest()
        .then((availableTags) => fetchDict(resolveLocale(desired, availableTags)))
        .catch(() => ({}))
        .then((dict) => {
          if (token !== this._renderToken) {
            return; // a newer render superseded this one
          }

          const template = dict[tid];
          if (template === undefined) {
            console.warn(`i18n-text: no translation for key "${tid}"`);
            this.textContent = tid;
            return;
          }

          this.textContent = substitute(template, values);
        });
    }
  }

  customElements.define('i18n-text', I18nTextElement);
})();
