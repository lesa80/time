import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const languages = ['ru', 'en', 'de', 'fr', 'es'];
const root = new URL('../', import.meta.url);
function strings(relative) {
  const source = fs.readFileSync(new URL(relative, root), 'utf8');
  const pairs = [...source.matchAll(/("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");/g)]
    .map(([, key, value]) => [JSON.parse(key), JSON.parse(value)]);
  assert.equal(new Set(pairs.map(([key]) => key)).size, pairs.length, `Duplicate translation: ${relative}`);
  return Object.fromEntries(pairs);
}
const catalogs = Object.fromEntries(languages.map(language => [language, strings(`macos/Resources/${language}.lproj/Localizable.strings`)]));

test('all five language resources have complete translations and matching format arguments', () => {
  const keys = Object.keys(catalogs.en).sort();
  assert(keys.length >= 100);
  const placeholders = value => value.match(/%(?:@|ld)/g) ?? [];
  for (const language of languages) {
    assert.deepEqual(Object.keys(catalogs[language]).sort(), keys, language);
    for (const key of keys) {
      assert(catalogs[language][key].trim(), `${language}: empty ${key}`);
      assert.deepEqual(placeholders(catalogs[language][key]), placeholders(key), `${language}: ${key}`);
    }
  }
});

test('every interface source string and theme name is included in the translation catalog', () => {
  const folder = new URL('macos/Sources/', root);
  for (const filename of fs.readdirSync(folder).filter(name => name.endsWith('.swift'))) {
    const source = fs.readFileSync(new URL(filename, folder), 'utf8');
    for (const [, quoted] of source.matchAll(/\bL\(("(?:[^"\\]|\\.)*")/g)) {
      const key = JSON.parse(quoted);
      assert(Object.hasOwn(catalogs.en, key), `${filename}: missing ${key}`);
    }
  }
  const localization = fs.readFileSync(new URL('macos/Sources/Localization.swift', root), 'utf8');
  const themes = JSON.parse(fs.readFileSync(new URL('themes.json', root)));
  for (const theme of themes.themes) {
    const match = localization.match(new RegExp(`"${theme.id}": "([^"]+)"`));
    assert(match, `Missing localized theme: ${theme.id}`);
    assert(Object.hasOwn(catalogs.en, match[1]), `Missing theme string: ${theme.id}`);
  }
});

test('localized bundle names and supported languages are declared for macOS', () => {
  const plist = fs.readFileSync(new URL('macos/Info.plist', root), 'utf8');
  assert.match(plist, /CFBundleDevelopmentRegion<\/key><string>en<\/string>/);
  for (const language of languages) {
    assert(plist.includes(`<string>${language}</string>`));
    const names = strings(`macos/Resources/${language}.lproj/InfoPlist.strings`);
    assert.equal(names.CFBundleDisplayName, language === 'ru' ? 'Время' : 'Vremya');
    assert.equal(names.CFBundleName, names.CFBundleDisplayName);
  }
});
