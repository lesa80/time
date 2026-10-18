import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { root, scratch, run, coreSources, appSources, compilerFlags, appName } from './lib/macos.mjs';

export function testNative(resources = path.join(root, 'dist/macos', `${appName}.app`, 'Contents/Resources')) {
  if (!fs.existsSync(path.join(resources, 'themes.json'))) throw new Error('Build Время.app before native interaction tests: npm run build');
  fs.mkdirSync(scratch, { recursive: true });
  const flags = compilerFlags();
  run('xcrun', ['swiftc', ...flags, ...coreSources, 'macos/Tests/main.swift', '-o', path.join(scratch, 'ClockTests')]);
  run(path.join(scratch, 'ClockTests'), []);
  // A real test bundle exercises the same Bundle.main localization lookup as the app.
  const testApp = path.join(scratch, 'InteractionTests.app');
  fs.rmSync(testApp, { recursive: true, force: true });
  const testResources = path.join(testApp, 'Contents/Resources');
  const testBinary = path.join(testApp, 'Contents/MacOS/InteractionTests');
  fs.mkdirSync(testResources, { recursive: true });
  fs.mkdirSync(path.dirname(testBinary), { recursive: true });
  fs.copyFileSync(path.join(root, 'macos/Info.plist'), path.join(testApp, 'Contents/Info.plist'));
  run('plutil', ['-replace', 'CFBundleExecutable', '-string', 'InteractionTests', path.join(testApp, 'Contents/Info.plist')]);
  for (const language of ['ru', 'en', 'de', 'fr', 'es']) {
    fs.cpSync(path.join(resources, `${language}.lproj`), path.join(testResources, `${language}.lproj`), { recursive: true });
  }
  run('xcrun', ['swiftc', ...flags, ...appSources, 'macos/Tests/Interaction/LocalizationChecks.swift',
    'macos/Tests/Interaction/main.swift', '-o', testBinary]);
  run(testBinary, [resources, '-AppleLanguages', '(en)']);
  for (const language of ['ru', 'en', 'de', 'fr', 'es']) {
    run(testBinary, [resources, '--localization-only', language, '-AppleLanguages', `(${language})`]);
  }
  run(testBinary, [resources, '--localization-only', 'en', '-AppleLanguages', '(pt-BR, ru)']);
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) testNative();
