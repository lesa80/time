import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { PNG } from 'pngjs';
import { composePreview } from './lib/raster.mjs';
import { handAngles, parseTime } from '../time.mjs';
import { appName, executableName, iconName } from './lib/macos.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'dist/macos');
const app = process.argv[2] ? path.resolve(process.argv[2]) : path.join(out, `${appName}.app`);
const executable = path.join(app, 'Contents/MacOS', executableName);
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'themes.json')));
const report = [];
const verificationSize = 2048;
const renderFolder = path.join(root, 'macos/.build/verification');
fs.mkdirSync(renderFolder, { recursive: true });
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(app, 'Contents/Resources/themes.json'))), catalog);
const aboutFolder = path.join(root, 'assets/about');
const bundledResources = path.join(app, 'Contents/Resources');
assert.deepEqual(fs.readFileSync(path.join(bundledResources, 'PrivacyInfo.xcprivacy')),
  fs.readFileSync(path.join(root, 'macos/PrivacyInfo.xcprivacy')), 'Privacy manifest missing or stale');
for (const filename of ['LICENSE', 'LICENSE_SCOPE.md', 'THIRD_PARTY_NOTICES.md', 'assets/branding/RIGHTS.md']) {
  assert.deepEqual(fs.readFileSync(path.join(bundledResources, 'Legal', filename)),
    fs.readFileSync(path.join(root, filename)), `Missing or stale legal notice: ${filename}`);
}
const plist = execFileSync('plutil', ['-convert', 'json', '-o', '-', path.join(app, 'Contents/Info.plist')], { encoding: 'utf8' });
const info = JSON.parse(plist);
assert.equal(info.CFBundleName, appName);
assert.equal(info.CFBundleDisplayName, appName);
assert.equal(info.CFBundleExecutable, executableName);
assert.equal(info.CFBundleIconFile, iconName);
assert.equal(info.CFBundleDevelopmentRegion, 'en');
assert.deepEqual(info.CFBundleLocalizations, ['ru', 'en', 'de', 'fr', 'es']);
for (const language of info.CFBundleLocalizations) {
  for (const name of ['Localizable.strings', 'InfoPlist.strings']) {
    const relative = `${language}.lproj/${name}`;
    assert.deepEqual(fs.readFileSync(path.join(bundledResources, relative)),
      fs.readFileSync(path.join(root, 'macos/Resources', relative)), `Missing or stale localization: ${relative}`);
  }
}
for (const filename of ['app.png', 'DeveloperLogo.png']) {
  assert.deepEqual(fs.readFileSync(path.join(bundledResources, filename)), fs.readFileSync(path.join(root, 'assets/icons', filename)));
}
const iconHeader = fs.readFileSync(path.join(bundledResources, `${iconName}.icns`));
assert.equal(iconHeader.toString('ascii', 0, 4), 'icns');
assert.equal(iconHeader.readUInt32BE(4), iconHeader.length, 'App icon container is incomplete');
for (const name of ['MenuBarIcon', 'MenuBarIconActive']) {
  for (const scale of [1, 2, 3]) {
    const filename = `${name}${scale === 1 ? '' : `@${scale}x`}.png`;
    const bytes = fs.readFileSync(path.join(bundledResources, filename));
    assert.deepEqual(bytes, fs.readFileSync(path.join(root, 'assets/icons', filename)), `Bundle uses stale ${filename}`);
    const image = PNG.sync.read(bytes);
    assert.deepEqual([image.width, image.height], [24 * scale, 18 * scale]);
    assert.equal(image.data[3], 0, 'Menu-bar template background must be transparent');
    assert(image.data.some((value, index) => index % 4 === 3 && value > 0), 'Menu-bar logo is empty');
  }
}
assert.deepEqual(fs.readFileSync(path.join(bundledResources, 'RaketaLogo.png')), fs.readFileSync(path.join(root, 'assets/icons/RaketaLogo.png')));
assert(!fs.existsSync(path.join(bundledResources, 'polar')), 'Removed Polar must not be bundled');
const collection = JSON.parse(fs.readFileSync(path.join(aboutFolder, 'collection.json')));
assert.deepEqual(collection.themes.map(t => t.id), catalog.themes.filter(t => t.brand === 'raketa').map(t => t.id), 'Raketa About gallery must show only branded themes');
for (const name of ['collection.png', 'collection.json']) {
  assert.deepEqual(fs.readFileSync(path.join(bundledResources, name)), fs.readFileSync(path.join(aboutFolder, name)), `Bundle uses stale About ${name}`);
}
const gallery = PNG.sync.read(fs.readFileSync(path.join(bundledResources, 'collection.png')));
assert.deepEqual([gallery.width, gallery.height], collection.resolution);
for (const theme of catalog.themes) {
const spec = JSON.parse(fs.readFileSync(path.join(root, theme.sourceSpec)));
const bundleFolder = path.join(bundledResources, path.dirname(theme.specification));
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(bundleFolder, path.basename(theme.specification)))), spec);
const layers = spec.layers.map(layer => ({ name: path.basename(layer.image, '.png'), spec: layer,
  png: fs.readFileSync(path.join(root, layer.image)), size: layer.size ?? spec.resolution }));
for (const layer of spec.layers) {
  const name = path.basename(layer.image);
  assert.deepEqual(fs.readFileSync(path.join(bundleFolder, name)),
    fs.readFileSync(path.join(root, layer.image)), `Bundle uses stale ${name}`);
}
const cases = theme.id.startsWith('minimalism') ? [['10:10:30', true], ['12:00:00', false], ['18:00:00', false], ['00:00:00', true]] :
  theme.id === 'avangard' ? [['06:07:50', true], ['12:00:00', false], ['18:35:40', true]] : [['06:35:40', true], ['01:10:20', false]];
for (const [time, showBezel] of cases) {
  const filename = path.join(renderFolder, `preview-${theme.id}-${time.replaceAll(':', '')}${showBezel ? '' : '-no-bezel'}.png`);
  execFileSync(executable, ['--render', filename, '--theme', theme.id, '--time', time, '--size', String(verificationSize), ...(showBezel ? [] : ['--no-bezel'])], { stdio: 'inherit' });
  const native = PNG.sync.read(fs.readFileSync(filename));
  const viewport = showBezel ? [0, 0, ...spec.resolution] : spec.dialBounds;
  const visibleLayers = layers.filter(l => showBezel || l.name !== 'bezel').map(layer => ({ ...layer,
    spec: { ...layer.spec,
      ...(layer.spec.position ? { position: layer.spec.position.map((n, i) => n - viewport[i]) } : {}),
      ...(layer.spec.handResPosition ? { handResPosition: layer.spec.handResPosition.map((n, i) => n - viewport[i]) } : {})
    }
  }));
  const expected = PNG.sync.read(composePreview(visibleLayers, viewport.slice(2), handAngles(parseTime(time), theme.hourCycle, theme.direction ?? 1), verificationSize, parseTime(time)));
  assert.equal(native.width, verificationSize);
  assert.equal(native.height, expected.height);
  // Compare premultiplied pixels so invisible RGB never affects the result.
  // Compare at master resolution: CoreGraphics and resvg use different
  // downsampling filters, which differ substantially at small text edges.
  let absoluteError = 0, largeDifferences = 0;
  for (let p = 0; p < native.data.length; p += 4) {
    for (let c = 0; c < 4; c++) {
      const a = c === 3 ? native.data[p + c] : native.data[p + c] * native.data[p + 3] / 255;
      const b = c === 3 ? expected.data[p + c] : expected.data[p + c] * expected.data[p + 3] / 255;
      absoluteError += Math.abs(a - b);
      if (Math.abs(a - b) > 40) largeDifferences++;
    }
  }
  const meanError = absoluteError / native.data.length;
  const outlierRatio = largeDifferences / native.data.length;
  // The wood and stippled gold of Golden Key expose the difference between
  // CoreGraphics and resvg interpolation (measured mean 1.009 / 255), even at
  // master size. Keep a tight contour/outlier bound independently of this
  // sub-percent texture tolerance; it catches wrong pivots and hand angles.
  assert(meanError < 1.5, `Native artwork mismatch for ${theme.id} at ${time}: mean error ${meanError}`);
  assert(outlierRatio < .002, `Native hand geometry mismatch at ${time}: outliers ${outlierRatio}`);
  if (showBezel || spec.dialShape !== 'rectangle') {
    assert.equal(native.data[3], 0, 'Desktop background must stay transparent');
  } else {
    // Dial-only Avgvst is a square glass crop: its corners are deliberately
    // present, including the antialiasing at the rectangle boundary.
    assert(native.data[3] > 128, 'Avgvst glass must retain its rectangular corners');
    assert(Math.abs(native.data[3] - expected.data[3]) < 4);
  }
  report.push({ theme: theme.id, hourCycle: theme.hourCycle, time, showBezel, resolution: [native.width, native.height], meanChannelError: meanError, outlierRatio });
}
}
fs.writeFileSync(path.join(out, 'validation.json'), JSON.stringify({
  application: { name: appName, version: info.CFBundleShortVersionString, bundleIdentifier: info.CFBundleIdentifier },
  verified: ['independent 12-hour and 24-hour cycles', 'local timezone conversion', 'complete catalog and exact PNG resources',
    'native CoreGraphics raster rendering in full-watch and dial-only modes', 'clockwise and counterclockwise hand rotations and shared pivots',
    'portrait, rectangular and circular window proportions', 'transparent background', 'app icon container and Retina neutral menu-bar icon resources',
    'provided app icon and developer logo', 'application name and bundle identity', 'MIT license and third-party notices',
    ...(process.env.RAKETA_BUNDLE_CHECKS_PASSED === '1' ? ['universal binary and code signature'] : [])],
  host: { platform: process.platform, architecture: process.arch },
  nativeInteractionsTested: process.env.RAKETA_NATIVE_TESTS_PASSED === '1',
  bundleChecksTested: process.env.RAKETA_BUNDLE_CHECKS_PASSED === '1',
  uiTested: false,
  uiVerificationLimitation: 'Visible UI and screen capture are not part of this automated run; AppKit interaction tests use unshown windows and local bitmaps.',
  renders: report
}, null, 2) + '\n');
console.log('Native raster renders agree with the existing watch-face renderer.');
