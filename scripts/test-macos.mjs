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
  run('xcrun', ['swiftc', ...flags, ...appSources, 'macos/Tests/Interaction/main.swift', '-o', path.join(scratch, 'InteractionTests')]);
  run(path.join(scratch, 'InteractionTests'), [resources]);
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) testNative();
