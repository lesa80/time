import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { composePreview } from './lib/raster.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'themes.json')));
catalog.themes = catalog.themes.filter(theme => theme.brand === 'raketa');
const columns = 8, cellWidth = 240, cellHeight = 340;
const rows = Math.ceil(catalog.themes.length / columns);
const escape = text => text.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c]));
const images = catalog.themes.map((theme, index) => {
  const spec = JSON.parse(fs.readFileSync(path.join(root, theme.sourceSpec)));
  const layers = spec.layers.map(layer => ({ name: path.basename(layer.image, '.png'), spec: layer,
    png: fs.readFileSync(path.join(root, layer.image)), size: layer.size ?? spec.resolution }));
  const png = composePreview(layers, spec.resolution, theme.referenceAngles, 280);
  const row = Math.floor(index / columns), col = index % columns;
  const countInRow = Math.min(columns, catalog.themes.length - row * columns);
  const x = (col + (columns - countInRow) / 2) * cellWidth, y = row * cellHeight;
  const [title, ...details] = theme.title.split(' · ');
  return `<image x="${x + 12}" y="${y + 10}" width="216" height="278" href="data:image/png;base64,${png.toString('base64')}"/>
    <text x="${x + cellWidth / 2}" y="${y + 310}" text-anchor="middle" fill="#f3f1ec" font-size="13">${escape(title)}</text>
    <text x="${x + cellWidth / 2}" y="${y + 328}" text-anchor="middle" fill="#9ea5ac" font-size="12">${escape(details.join(' · '))}</text>`;
}).join('');
const width = columns * cellWidth, height = rows * cellHeight;
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" font-family="Helvetica,Arial,sans-serif"><rect width="100%" height="100%" rx="20" fill="#202124"/>${images}</svg>`;
const folder = path.join(root, 'assets/about');
fs.mkdirSync(folder, { recursive: true });
fs.writeFileSync(path.join(folder, 'collection.png'), new Resvg(svg, { font: { loadSystemFonts: true } }).render().asPng());
fs.writeFileSync(path.join(folder, 'collection.json'), JSON.stringify({ resolution: [width, height], themes: catalog.themes.map(t => ({ id: t.id, title: t.title })), source: 'themes.json; original full-watch raster layers' }, null, 2) + '\n');
console.log(`Prepared About collection: ${catalog.themes.length} watches, ${width} × ${height}.`);
