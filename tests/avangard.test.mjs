import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import { PNG } from 'pngjs';

const spec = JSON.parse(fs.readFileSync(new URL('../assets/avangard/theme.json', import.meta.url)));
function handPixel(name, dx, dy) {
  const layer = spec.layers.find(l => l.image.endsWith(`/${name}.png`));
  const png = PNG.sync.read(fs.readFileSync(new URL(`../${layer.image}`, import.meta.url)));
  const x = Math.floor((layer.rotatePoint[0] + dx) / layer.size[0] * png.width);
  const y = Math.floor((layer.rotatePoint[1] + dy) / layer.size[1] * png.height);
  return [...png.data.subarray((y * png.width + x) * 4, (y * png.width + x) * 4 + 4)];
}

test('Avangard has independent geometric hour, minute and second sprites', () => {
  assert.equal(spec.hourCycle, 12);
  assert.equal(spec.layers.filter(l => l.type === 'Hand Res').length, 3);
  assert.equal(handPixel('hour', 0, -110)[3], 0, 'triangle aperture must remain see-through');
  assert(handPixel('hour', 0, -230)[3] > 240, 'triangle tip has a luminous inset');
  assert.equal(handPixel('minute', 0, -115)[3], 0, 'large ring aperture must remain see-through');
  const marker = handPixel('minute', 0, -224);
  assert(marker[3] > 240 && Math.min(...marker.slice(0, 3)) > 160, 'white minute indicator must be opaque');
  const cap = PNG.sync.read(fs.readFileSync(new URL('../assets/avangard/cap.png', import.meta.url)));
  assert.equal(cap.data[(Math.floor(cap.height / 2) * cap.width + Math.floor(cap.width / 2)) * 4 + 3], 255, 'central pin is opaque');
});

test('full watch mode includes the original leather strap and leaves the old hands out', () => {
  const body = PNG.sync.read(fs.readFileSync(new URL('../assets/avangard/bezel.png', import.meta.url)));
  assert.deepEqual([body.width, body.height], [716, 1194]);
  const alpha = (x, y) => body.data[(y * body.width + x) * 4 + 3];
  assert.equal(alpha(338, 574), 0, 'original fixed hands must be absent under the live face');
  assert(alpha(338, 60) > 240, 'upper leather strap remains');
  assert(alpha(338, 1100) > 240, 'lower leather strap remains');
  assert.equal(alpha(0, 0), 0);
});

test('native catalog themes and the standalone browser bundle use the same registry', () => {
  const catalog = JSON.parse(fs.readFileSync(new URL('../themes.json', import.meta.url)));
  assert.equal(catalog.themes.find(t => t.id === 'minimalism').hourCycle, 12);
  assert.equal(catalog.themes.find(t => t.id === 'avangard').hourCycle, 12);
  assert.equal(catalog.defaultTheme, 'minimalism-24-dark');
  const bundle = fs.readFileSync(new URL('../preview.js', import.meta.url), 'utf8');
  assert(!/^import /m.test(bundle), 'file preview must not require module fetching');
  for (const theme of catalog.themes) assert(bundle.includes(JSON.stringify(theme.title)));
});
