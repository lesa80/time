import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import { createHash } from 'node:crypto';
import { PNG } from 'pngjs';

const read = relative => fs.readFileSync(new URL(`../${relative}`, import.meta.url));
test('the supplied developer logo and app artwork remain intact and attributable', () => {
  const sources = JSON.parse(read('assets/branding/sources.json'));
  for (const entry of sources.images) {
    const bytes = read(`assets/branding/${entry.file}`);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), entry.sha256);
  }
  assert.deepEqual(read('assets/icons/DeveloperLogo.png'), read('assets/branding/bolt42.png'));
  const svg = read('assets/icons/app.svg').toString('utf8');
  assert(svg.includes(read('assets/branding/time-icon.png').toString('base64')), 'Icon must use the exact supplied artwork');
});

test('the macOS icon has transparent outer margins, a cream tile and the provided red clock hub', () => {
  const png = PNG.sync.read(read('assets/icons/app.png'));
  assert.deepEqual([png.width, png.height], [1024, 1024]);
  const at = (x, y) => [...png.data.subarray((y * png.width + x) * 4, (y * png.width + x) * 4 + 4)];
  assert.equal(at(0, 0)[3], 0);
  assert.equal(at(512, 4)[3], 0);
  const cream = at(150, 150);
  assert(cream[0] > 235 && cream[1] > 225 && cream[2] > 200 && cream[3] === 255);
  const hub = at(512, 500);
  assert(hub[0] > 150 && hub[1] < 70 && hub[2] < 70 && hub[3] === 255, `Provided red hub missing: ${hub}`);
});
