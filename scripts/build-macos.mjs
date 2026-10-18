import fs from 'node:fs';
import path from 'node:path';
import { root, scratch, run, appSources, compilerFlags, appName, executableName, iconName, archiveName } from './lib/macos.mjs';
import { testNative } from './test-macos.mjs';

if (process.platform !== 'darwin') throw new Error('The native macOS app must be built on macOS with Command Line Tools.');
const output = path.join(root, 'dist/macos');
const publishedApp = path.join(output, `${appName}.app`);
const app = path.join(scratch, `staging/${appName}.app`);
const contents = path.join(app, 'Contents');
const resources = path.join(contents, 'Resources');
// Assemble a fresh bundle, never carrying stale resources or executables forward.
fs.rmSync(app, { recursive: true, force: true });
fs.mkdirSync(resources, { recursive: true });
fs.mkdirSync(path.join(contents, 'MacOS'), { recursive: true });
fs.mkdirSync(scratch, { recursive: true });
fs.mkdirSync(output, { recursive: true });
const sources = [...appSources, 'macos/Sources/main.swift'];
const common = compilerFlags();

// UI-only rebuilds can reuse the already prepared watch-face artwork.
if (!process.argv.includes('--reuse-artwork')) {
  run(process.execPath, [path.join(root, 'scripts/prepare-minimalism.mjs')]);
  run(process.execPath, [path.join(root, 'scripts/prepare-avangard.mjs')]);
  run(process.execPath, [path.join(root, 'scripts/prepare-catalog.mjs')]);
}
run(process.execPath, [path.join(root, 'scripts/build-preview.mjs')]);
run(process.execPath, [path.join(root, 'scripts/prepare-about.mjs')]);
run(process.execPath, [path.join(root, 'scripts/prepare-icons.mjs')]);

const architectures = ['arm64', 'x86_64'];
for (const arch of architectures) {
  run('xcrun', ['swiftc', ...common, '-target', `${arch}-apple-macosx13.0`, ...sources,
    '-o', path.join(scratch, `${executableName}-${arch}`)]);
}
run('xcrun', ['lipo', '-create', ...architectures.map(a => path.join(scratch, `${executableName}-${a}`)),
  '-output', path.join(contents, 'MacOS', executableName)]);
fs.copyFileSync(path.join(root, 'macos/Info.plist'), path.join(contents, 'Info.plist'));
fs.copyFileSync(path.join(root, 'themes.json'), path.join(resources, 'themes.json'));
fs.copyFileSync(path.join(root, 'macos/PrivacyInfo.xcprivacy'), path.join(resources, 'PrivacyInfo.xcprivacy'));
const legal = path.join(resources, 'Legal');
fs.mkdirSync(legal, { recursive: true });
for (const filename of ['LICENSE', 'LICENSE_SCOPE.md', 'THIRD_PARTY_NOTICES.md', 'assets/branding/RIGHTS.md']) {
  fs.mkdirSync(path.dirname(path.join(legal, filename)), { recursive: true });
  fs.copyFileSync(path.join(root, filename), path.join(legal, filename));
}
run('plutil', ['-lint', path.join(resources, 'PrivacyInfo.xcprivacy')]);
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'themes.json')));
for (const theme of catalog.themes) {
  const folder = path.join(resources, path.dirname(theme.specification));
  fs.mkdirSync(folder, { recursive: true });
  fs.copyFileSync(path.join(root, theme.sourceSpec), path.join(resources, theme.specification));
  const spec = JSON.parse(fs.readFileSync(path.join(root, theme.sourceSpec)));
  for (const layer of spec.layers) fs.copyFileSync(path.join(root, layer.image), path.join(folder, path.basename(layer.image)));
}
fs.copyFileSync(path.join(root, 'assets/about/collection.png'), path.join(resources, 'collection.png'));
fs.copyFileSync(path.join(root, 'assets/about/collection.json'), path.join(resources, 'collection.json'));
const iconset = path.join(scratch, `${iconName}.iconset`);
for (const filename of fs.readdirSync(path.join(root, 'assets/icons')).filter(name => /^(MenuBarIcon.*|RaketaLogo|DeveloperLogo|app)\.png$/.test(name))) {
  fs.copyFileSync(path.join(root, 'assets/icons', filename), path.join(resources, filename));
}
run('iconutil', ['-c', 'icns', iconset, '-o', path.join(resources, `${iconName}.icns`)]);
run('plutil', ['-lint', path.join(contents, 'Info.plist')]);
const identity = process.env.VREMYA_SIGN_IDENTITY || process.env.RAKETA_SIGN_IDENTITY || '-';
run('codesign', ['--force', '--options', 'runtime', '--sign', identity,
  ...(identity === '-' ? [] : ['--timestamp']), app]);
run('codesign', ['--verify', '--deep', '--strict', app]);
testNative(resources);
run(process.execPath, ['--test', ...fs.readdirSync(path.join(root, 'tests')).filter(f => f.endsWith('.test.mjs')).map(f => `tests/${f}`)]);
run(process.execPath, [path.join(root, 'scripts/verify-macos.mjs'), app], { env: {
  ...process.env, RAKETA_NATIVE_TESTS_PASSED: '1', RAKETA_BUNDLE_CHECKS_PASSED: '1'
} });
const zip = path.join(output, archiveName);
const stagedZip = path.join(scratch, archiveName);
fs.rmSync(stagedZip, { force: true });
run('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', app, stagedZip]);
// Keep the previous release usable until compilation, tests and packaging pass.
fs.rmSync(publishedApp, { recursive: true, force: true });
fs.renameSync(app, publishedApp);
fs.renameSync(stagedZip, zip);
console.log(`Built universal macOS app: ${publishedApp}\nArchive: ${zip}`);
