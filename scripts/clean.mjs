import fs from 'node:fs';
import path from 'node:path';
import { root } from './lib/macos.mjs';

// Only derived output is removed. Raster masters and ready-to-use theme layers stay.
for (const relative of ['dist', 'macos/.build', 'preview.js', 'themes-data.mjs']) {
  fs.rmSync(path.join(root, relative), { recursive: true, force: true });
}
console.log('Removed build output and caches. Source artwork and theme resources retained.');
