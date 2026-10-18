import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { PNG } from 'pngjs';
import { resample, resampleWarped } from './lib/raster.mjs';
import { composePreview } from './lib/raster.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const folder = path.join(root, 'assets/avangard');
fs.mkdirSync(path.join(root, 'macos/.build/previews'), { recursive: true });
const side = 2048, logical = 588, scale = side / logical;
const bodyCrop = [112, 126, 716, 1194], resolution = bodyCrop.slice(2);
const center = [450 - bodyCrop[0], 700 - bodyCrop[1]], origin = center.map(n => n - logical / 2);
const read = file => PNG.sync.read(fs.readFileSync(file));
const save = (name, png) => fs.writeFileSync(path.join(folder, `${name}.png`), PNG.sync.write(png));
const source = name => read(path.join(folder, 'source', `${name}.png`));

function bounds(png, threshold = 128) {
  const b = [png.width, png.height, -1, -1];
  for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
    if (png.data[(y * png.width + x) * 4 + 3] < threshold) continue;
    b[0] = Math.min(b[0], x); b[1] = Math.min(b[1], y);
    b[2] = Math.max(b[2], x); b[3] = Math.max(b[3], y);
  }
  return b;
}
function cleanMatte(png) {
  for (let i = 0; i < png.data.length; i += 4) {
    const [r, g, b, a] = png.data.subarray(i, i + 4);
    if (a < 3 || (a <= 12 && Math.max(r, g, b) - Math.min(r, g, b) < 30)) png.data.fill(0, i, i + 4);
  }
  return png;
}
function ellipseMask(png, cx, cy, rx, ry, invert = false) {
  for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
    let coverage = Math.max(0, Math.min(1, (1 - Math.hypot((x + .5 - cx) / rx, (y + .5 - cy) / ry)) * Math.min(rx, ry) + .5));
    if (invert) coverage = 1 - coverage;
    const i = (y * png.width + x) * 4;
    png.data[i + 3] = Math.round(png.data[i + 3] * coverage);
    if (!png.data[i + 3]) png.data.fill(0, i, i + 4);
  }
  return png;
}
function place(target, sprite, x, y) {
  x = Math.round(x); y = Math.round(y);
  for (let sy = 0; sy < sprite.height; sy++) for (let sx = 0; sx < sprite.width; sx++) {
    const tx = x + sx, ty = y + sy;
    if (tx < 0 || tx >= target.width || ty < 0 || ty >= target.height) continue;
    const si = (sy * sprite.width + sx) * 4, di = (ty * target.width + tx) * 4;
    const a = sprite.data[si + 3] / 255, b = target.data[di + 3] / 255, out = a + b * (1 - a);
    if (!out) continue;
    for (let c = 0; c < 3; c++) target.data[di + c] = Math.round((sprite.data[si + c] * a + target.data[di + c] * b * (1 - a)) / out);
    target.data[di + 3] = Math.round(out * 255);
  }
}

const specs = [];
function saveHand(name, png, pivot) {
  cleanMatte(png);
  const b = bounds(png, 3), padding = 5;
  const x = Math.max(0, b[0] - padding), y = Math.max(0, b[1] - padding);
  const width = Math.min(png.width - x, b[2] - x + padding + 1);
  const height = Math.min(png.height - y, b[3] - y + padding + 1);
  // Crop without resampling: original high-resolution cutout pixels are retained.
  const crop = new PNG({ width, height });
  for (let row = 0; row < height; row++) {
    png.data.copy(crop.data, row * width * 4, ((row + y) * png.width + x) * 4, ((row + y) * png.width + x + width) * 4);
  }
  save(name, crop);
  const layer = { type: 'Hand Res', image: `assets/avangard/${name}.png`,
    valueType: name === 'hour' ? 'Hour 12 Ratio' : name === 'minute' ? 'Minute Ratio' : 'Second Ratio',
    handResPosition: center, rotatePoint: [(pivot[0] - x) / scale, (pivot[1] - y) / scale],
    size: [width / scale, height / scale], angle: [0, 360] };
  specs.push(layer);
  return { crop, layer };
}

const dialSource = source('dial');
save('dial', ellipseMask(resample(dialSource, [0, 0, dialSource.width, dialSource.height], side, side), side / 2, side / 2, side / 2, side / 2));

const photo = read(path.join(root, 'reference/avangard/front.png'));
const bezel = resample(photo, bodyCrop, ...resolution);
ellipseMask(bezel, ...center, 292, 292, true);
save('bezel', bezel);

// Register the red triangle by its mounting eye; the axis is near its base.
const hour = source('hour');
const hb = bounds(hour);
let eyeX = (hb[0] + hb[2]) / 2, eyeY = hb[3] - (hb[2] - hb[0]) * .08;
// Locate the transparent circular aperture below the large triangular opening.
const hourCenterX = Math.round(eyeX);
const eyeRows = [];
for (let y = Math.round(hb[1] + (hb[3] - hb[1]) * .85); y < hb[3]; y++) {
  const a = hour.data[(y * hour.width + hourCenterX) * 4 + 3];
  if (a < 16) eyeRows.push(y);
}
if (eyeRows.length) {
  let groups = [], group = [];
  for (const y of eyeRows) { if (group.length && y > group.at(-1) + 1) { groups.push(group); group = []; } group.push(y); }
  groups.push(group);
  const ringHole = groups.filter(g => g.length > 8).at(-1);
  if (ringHole) eyeY = (ringHole[0] + ringHole.at(-1)) / 2;
}
const sx = 207 / (hb[2] - hb[0] + 1), sy = 263 / (eyeY - hb[1]);
saveHand('hour', resample(hour, [eyeX - 294 / sx, eyeY - 294 / sy, logical / sx, logical / sy], side, side), [side / 2, side / 2]);

// Register the generated ring texture to the reference dimensions. The marker
// and mounting neck are composited separately so the minute pivot is not the
// geometric centre of the large circle.
const minuteSource = source('minute');
const mb = bounds(minuteSource), mx = (mb[0] + mb[2]) / 2;
const mainRadius = (mb[2] - mb[0] + 1) / 2;
const mainCenterY = mb[3] - mainRadius;
const ring = new PNG({ width: side, height: side });
const ringRadius = 141 * scale, ringCX = side / 2, ringCY = (294 - 115) * scale;
const ringTexture = resample(minuteSource, [mx - ringCX * mainRadius / ringRadius,
  mainCenterY - ringCY * mainRadius / ringRadius, side * mainRadius / ringRadius, side * mainRadius / ringRadius], side, side);
for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) {
  const distance = Math.hypot(x + .5 - ringCX, y + .5 - ringCY);
  const outer = Math.max(0, Math.min(1, ringRadius + .5 - distance));
  const inner = Math.max(0, Math.min(1, distance - (141 - 10) * scale + .5));
  const i = (y * side + x) * 4;
  ring.data.set(ringTexture.data.subarray(i, i + 4), i);
  // Sample the same opaque matte-rim texture throughout the registered annulus.
  // Its own generated alpha can otherwise leave a gap at the old marker joint.
  if ((ring.data[i + 3] < 200 || Math.min(...ring.data.subarray(i, i + 3)) > 100) && outer * inner > 0) {
    const sampleY = Math.round(mainCenterY), sampleX = Math.round(mx + mainRadius - 18);
    const j = (sampleY * minuteSource.width + sampleX) * 4;
    ring.data.set(minuteSource.data.subarray(j, j + 3), i);
  }
  ring.data[i + 3] = Math.round(255 * outer * inner);
}
// Locate the white marker's centroid from the cutout's opaque pale pixels.
let markerX = 0, markerY = 0, markerCount = 0;
for (let y = mb[1]; y < mainCenterY - mainRadius * .55; y++) for (let x = Math.floor(mx - mainRadius * .3); x < mx + mainRadius * .3; x++) {
  const i = (y * minuteSource.width + x) * 4;
  if (minuteSource.data[i + 3] > 220 && Math.min(...minuteSource.data.subarray(i, i + 3)) > 160) {
    markerX += x; markerY += y; markerCount++;
  }
}
assert(markerCount > 100, 'Minute luminous indicator missing');
markerX /= markerCount; markerY /= markerCount;
const markerSourceRadius = Math.sqrt(markerCount / Math.PI) * 1.35;
const markerSize = Math.round(56 * scale);
const marker = ellipseMask(resample(minuteSource, [markerX - markerSourceRadius, markerY - markerSourceRadius,
  markerSourceRadius * 2, markerSourceRadius * 2], markerSize, markerSize), markerSize / 2, markerSize / 2, markerSize / 2, markerSize / 2);
place(ring, marker, ringCX - markerSize / 2, (294 - 224) * scale - markerSize / 2);
const stemWidth = Math.round(8 * scale), stemHeight = Math.round(27 * scale);
const stem = resample(minuteSource, [mx - 8, mainCenterY + mainRadius - 35, 16, 12], stemWidth, stemHeight);
place(ring, stem, side / 2 - stemWidth / 2, side / 2);
saveHand('minute', ring, [side / 2, side / 2]);

const secondSource = source('second');
const sb = bounds(secondSource), secondX = (sb[0] + sb[2]) / 2;
let capWidth = 0;
const widths = [];
for (let y = Math.round(secondSource.height * .5); y < secondSource.height * .85; y++) {
  let width = 0;
  for (let x = sb[0]; x <= sb[2]; x++) if (secondSource.data[(y * secondSource.width + x) * 4 + 3] >= 128) width++;
  capWidth = Math.max(capWidth, width); widths.push([y, width]);
}
const capRows = widths.filter(([, width]) => width >= capWidth * .95).map(([y]) => y);
const secondPivotY = (capRows[0] + capRows.at(-1)) / 2;
const headScale = 64 / (sb[2] - sb[0] + 1), shaftScale = 6 / 27;
const secondGeometry = {
  size: [Math.round(90 * scale), Math.round(370 * scale)], pivot: [45 * scale, 290 * scale], masterPivot: [secondX, secondPivotY],
  sourceYKnots: [[11 * scale, sb[1]], [290 * scale, secondPivotY], [360 * scale, sb[3]]],
  targetXScaleKnots: [[0, headScale * scale], [72 * scale, headScale * scale], [90 * scale, shaftScale * scale], [370 * scale, shaftScale * scale]]
};
saveHand('second', resampleWarped(secondSource, secondGeometry), secondGeometry.pivot);

const capSize = Math.round(16 * scale);
const cap = resample(secondSource, [secondX - capWidth / 2, secondPivotY - capWidth / 2, capWidth, capWidth], capSize, capSize);
// The central pin is opaque; a cutout hole in the isolated second hand must
// not reveal the red mounting eye of the hour hand beneath the cap.
for (let i = 3; i < cap.data.length; i += 4) cap.data[i] = 255;
ellipseMask(cap, capSize / 2, capSize / 2, capSize / 2, capSize / 2);
save('cap', cap);
const spec = {
  name: 'Raketa Avangard 0292', target: 'macOS / Retina', hourCycle: 12, resolution,
  dialBounds: [...origin, logical, logical], rasterResolution: [side, side], referenceTime: '06:07:50',
  layers: [
    { type: 'Single Res', image: 'assets/avangard/bezel.png', position: [0, 0], size: resolution },
    { type: 'Single Res', image: 'assets/avangard/dial.png', position: origin, size: [logical, logical] },
    ...specs,
    { type: 'Single Res', image: 'assets/avangard/cap.png', position: center.map(n => n - 8), size: [16, 16] }
  ]
};
fs.writeFileSync(path.join(folder, 'theme.json'), JSON.stringify(spec, null, 2) + '\n');
fs.writeFileSync(path.join(folder, 'registration.json'), JSON.stringify({
  hour: { bounds: hb, pivot: [eyeX, eyeY], tipRadius: 263, width: 207 },
  minute: { bounds: mb, ringCenter: [mx, mainCenterY], ringRadius: mainRadius, markerCenter: [markerX, markerY],
    logicalRingCenter: [294, 179], logicalRingRadius: 141, logicalMarkerCenter: [294, 70], logicalPivot: [294, 294] },
  second: { bounds: sb, pivot: [secondX, secondPivotY], tipRadius: 279, counterRadius: 70 }
}, null, 2) + '\n');
const layers = spec.layers.map(layer => ({ name: path.basename(layer.image, '.png'), spec: layer,
  png: fs.readFileSync(path.join(root, layer.image)), size: layer.size }));
const angles = { hour: 181.8, minute: 47, second: 300.5 };
for (const size of [466, 2048]) fs.writeFileSync(path.join(root, `macos/.build/previews/avangard-preview${size === 466 ? '-466' : ''}.png`), composePreview(layers, spec.resolution, angles, size));
fs.writeFileSync(path.join(root, 'macos/.build/previews/avangard-preview-280.png'), composePreview(layers, spec.resolution, angles, 280));
const dialLayers = layers.filter(l => l.name !== 'bezel').map(layer => ({ ...layer, spec: { ...layer.spec,
  ...(layer.spec.position ? { position: layer.spec.position.map((n, i) => n - origin[i]) } : {}),
  ...(layer.spec.handResPosition ? { handResPosition: layer.spec.handResPosition.map((n, i) => n - origin[i]) } : {})
} }));
for (const size of [466, 2048]) fs.writeFileSync(path.join(root, `macos/.build/previews/avangard-dial-preview${size === 466 ? '-466' : ''}.png`), composePreview(dialLayers, [logical, logical], angles, size));
console.log('Prepared Avangard 0292: 2048px raster dial, three independently registered geometric hands, 12-hour movement.');
