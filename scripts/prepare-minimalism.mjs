import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { composePreview } from './lib/raster.mjs';
import { bolt42DialBranding } from './lib/bolt42.mjs';
import { handAngles, parseTime } from '../time.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceFolder = path.join(root, 'assets/minimalism/source');
const registration = JSON.parse(fs.readFileSync(path.join(sourceFolder, 'case-registration.json')));
const { canvas, sourceOffset, dialBounds } = registration;
const [dialX, dialY, dialWidth, dialHeight] = dialBounds;
const center = [dialX + dialWidth / 2, dialY + dialHeight / 2];
const scale = dialWidth / 2048;
const variants = [
  { id: 'minimalism', title: 'Минимализм', hourCycle: 12, fontSize: 172 },
  { id: 'minimalism-24', title: 'Минимализм 24', hourCycle: 24, fontSize: 154 },
  { id: 'minimalism-dark', title: 'Минимализм — тёмный', hourCycle: 12, fontSize: 172, dark: true },
  { id: 'minimalism-24-dark', title: 'Минимализм 24 — тёмный', hourCycle: 24, fontSize: 154, dark: true }
];
const svg = (width, height, content) => `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${content}</svg>`;
function write(folder, name, width, height, content) {
  const source = svg(width, height, content);
  fs.writeFileSync(path.join(folder, `${name}.svg`), source + '\n');
  fs.writeFileSync(path.join(folder, `${name}.png`), new Resvg(source, { font: { loadSystemFonts: true } }).render().asPng());
}
function sector(fromHour, toHour, color) {
  const point = (hour, radius) => {
    const angle = hour * Math.PI / 12;
    return [1024 + Math.sin(angle) * radius, 1024 - Math.cos(angle) * radius].join(' ');
  };
  // Hour values continue past midnight so 22–6 remains one seamless arc.
  return `<path d="M ${point(fromHour, 1015)} A 1015 1015 0 0 1 ${point(toHour, 1015)} L ${point(toHour, 963)} A 963 963 0 0 0 ${point(fromHour, 963)} Z" fill="${color}"/>`;
}
const entries = variants.map(({ id, title, hourCycle, fontSize, dark = false }) => {
  const base = `assets/${id}`;
  const folder = path.join(root, base);
  fs.mkdirSync(folder, { recursive: true });
  // Raster case is kept unchanged. The layer offset trims transparent margins;
  // live dial and hand coordinates are registered to its circular alpha aperture.
  fs.copyFileSync(path.join(sourceFolder, 'case.png'), path.join(folder, 'bezel.png'));
  const daily = hourCycle === 24;
  const background = dark ? '#000000' : '#ffffff';
  const ink = dark ? '#ffffff' : '#111111';
  const sectors = daily ? sector(22, 30, '#dc2626') + sector(6, 10, '#ffffff') +
    sector(10, 18, '#2376bd') + sector(18, 22, '#ffffff') : '';
  const tickShapes = Array.from({ length: 60 }, (_, i) => {
    if (daily) return `<rect x="1021" y="24" width="6" height="24" transform="rotate(${i * 6} 1024 1024)"/>`;
    const major = i % 5 === 0;
    return `<rect x="${1024 - (major ? 9 : 4)}" y="44" width="${major ? 18 : 8}" height="${major ? 64 : 32}" fill="${ink}" transform="rotate(${i * 6} 1024 1024)"/>`;
  }).join('');
  // Clip the dark copy to the white sectors. Marks on a sector boundary
  // receive the correct contrasting color on each half, without shifting them.
  const ticks = daily ? `<defs><clipPath id="white-sectors">${sector(6, 10, '#ffffff')}${sector(18, 22, '#ffffff')}</clipPath></defs>` +
    `<g fill="#ffffff">${tickShapes}</g><g fill="#111111" clip-path="url(#white-sectors)">${tickShapes}</g>` : tickShapes;
  const hourMarks = daily ? Array.from({ length: 24 }, (_, hour) => {
    if (hour % 4 === 0) return '';
    const major = hour % 4 === 2;
    return `<rect x="${1024 - (major ? 14 : 4)}" y="${major ? 192 : 224}" width="${major ? 28 : 8}" height="${major ? 112 : 40}" fill="${ink}" transform="rotate(${hour * 15} 1024 1024)"/>`;
  }).join('') : '';
  const numeralHours = daily ? [0, 4, 8, 12, 16, 20] : Array.from({ length: 12 }, (_, i) => i + 1);
  const numerals = numeralHours.map(hour => {
    const angle = hour * Math.PI * 2 / hourCycle;
    const text = String(hour);
    return `<text x="${1024 + Math.sin(angle) * 775}" y="${1024 - Math.cos(angle) * 775 + fontSize * .35}" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="${fontSize}" font-weight="700" fill="${ink}">${text}</text>`;
  }).join('');
  write(folder, 'dial', 2048, 2048,
    `<circle cx="1024" cy="1024" r="1019" fill="${background}" stroke="#747980" stroke-width="8"/>${sectors}${ticks}${hourMarks}${numerals}${bolt42DialBranding({ ink, dark })}`);
  write(folder, 'hour', 72, 700, `<rect x="6" y="0" width="60" height="700" fill="${ink}"/>`);
  write(folder, 'minute', 48, 960, `<rect x="8" y="0" width="32" height="960" fill="${ink}"/>`);
  write(folder, 'second', 28, 1120, '<rect x="9" y="0" width="10" height="1120" fill="#dc2626"/>');
  write(folder, 'cap', 52, 52, '<circle cx="26" cy="26" r="26" fill="#dc2626"/>');
  const layers = [
    { type: 'Single Res', image: `${base}/bezel.png`, position: sourceOffset, size: registration.sourceResolution },
    { type: 'Single Res', image: `${base}/dial.png`, position: [dialX, dialY], size: [dialWidth, dialHeight] }
  ];
  for (const [name, size, pivot] of [['hour', [72, 700], [36, 600]], ['minute', [48, 960], [24, 850]], ['second', [28, 1120], [14, 940]]]) {
    layers.push({ type: 'Hand Res', image: `${base}/${name}.png`, handResPosition: center,
      rotatePoint: pivot.map(n => n * scale), size: size.map(n => n * scale) });
  }
  layers.push({ type: 'Single Res', image: `${base}/cap.png`, position: center.map(n => n - 26 * scale), size: [52 * scale, 52 * scale] });
  const spec = { name: title, hourCycle, resolution: canvas, dialBounds, dialShape: 'circle', rasterResolution: [2048, 2048], layers };
  fs.writeFileSync(path.join(folder, 'theme.json'), JSON.stringify(spec, null, 2) + '\n');
  const theme = { id, title, hourCycle, specification: `${id}/theme.json`, sourceSpec: `${base}/theme.json`, referenceTime: '10:10:30', referenceAngles: handAngles(parseTime('10:10:30'), hourCycle) };
  const previewLayers = layers.map(spec => ({ name: path.basename(spec.image, '.png'), spec, png: fs.readFileSync(path.join(root, spec.image)), size: spec.size }));
  fs.writeFileSync(path.join(folder, 'preview-full.png'), composePreview(previewLayers, spec.resolution, theme.referenceAngles, 500));
  const dialLayers = previewLayers.filter(layer => layer.name !== 'bezel').map(layer => ({ ...layer, spec: { ...layer.spec,
    ...(layer.spec.position ? { position: layer.spec.position.map((n, i) => n - dialBounds[i]) } : {}),
    ...(layer.spec.handResPosition ? { handResPosition: layer.spec.handResPosition.map((n, i) => n - dialBounds[i]) } : {})
  } }));
  fs.writeFileSync(path.join(folder, 'preview.png'), composePreview(dialLayers, [dialWidth, dialHeight], theme.referenceAngles, 1024));
  return theme;
});
const registryPath = path.join(root, 'themes.json');
const registry = JSON.parse(fs.readFileSync(registryPath));
registry.defaultTheme = 'minimalism-24-dark';
registry.themes = [...entries, ...registry.themes.filter(t => !['polar', ...variants.map(v => v.id)].includes(t.id))];
fs.writeFileSync(registryPath, JSON.stringify(registry, null, 2) + '\n');
console.log('Prepared Minimalism 12h and 24h in light and dark: 2048px dials, contrasting hands, red seconds, original case and strap.');
