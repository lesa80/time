import fs from 'node:fs';
import path from 'node:path';
import { Resvg } from '@resvg/resvg-js';
import { root, scratch, iconName } from './lib/macos.mjs';

const output = path.join(root, 'assets/icons');
const iconset = path.join(scratch, `${iconName}.iconset`);
fs.mkdirSync(output, { recursive: true });
fs.mkdirSync(iconset, { recursive: true });

// Preserve the original wordmark contours. The source's right-hand anniversary
// emblem is outside this crop and is not part of the app's permanent identity.
const source = fs.readFileSync(path.join(root, 'assets/icons/logo.svg'), 'utf8');
const contours = source.match(/<path[\s\S]*?<\/path>/)[0];
const logo = (x, y, width, color) => `<svg x="${x}" y="${y}" width="${width}" height="${width * 78 / 323}" viewBox="0 0 323 78" overflow="hidden">${contours.replace('fill="#cf291c"', `fill="${color}"`)}</svg>`;
// Preserve the supplied artwork. Only standard macOS icon framing and size change.
const providedIcon = fs.readFileSync(path.join(root, 'assets/branding/time-icon.png'));
const appArtwork = `<defs><clipPath id="tile"><rect x="32" y="24" width="448" height="448" rx="100"/></clipPath><filter id="shadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dy="7" stdDeviation="7" flood-opacity=".2"/></filter></defs><rect x="32" y="24" width="448" height="448" rx="100" fill="#f8f3df" filter="url(#shadow)"/><image x="32" y="24" width="448" height="448" clip-path="url(#tile)" href="data:image/png;base64,${providedIcon.toString('base64')}"/>`;
const svg = (width, height, content, viewBox = `0 0 ${width} ${height}`) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="${viewBox}">${content}</svg>`;
const render = (document, destination) => fs.writeFileSync(destination,
  new Resvg(document, { font: { loadSystemFonts: false } }).render().asPng());
fs.writeFileSync(path.join(output, 'app.svg'), svg(1024, 1024, appArtwork, '0 0 512 512'));
for (const points of [16, 32, 128, 256, 512]) {
  for (const scale of [1, 2]) {
    const pixels = points * scale;
    render(svg(pixels, pixels, appArtwork, '0 0 512 512'),
      path.join(iconset, `icon_${points}x${points}${scale === 2 ? '@2x' : ''}.png`));
  }
}
fs.copyFileSync(path.join(iconset, 'icon_512x512@2x.png'), path.join(output, 'app.png'));

// Template alpha masks let AppKit choose the correct menu-bar foreground color.
const trayArtwork = active => '<circle cx="9" cy="9" r="7.1" fill="none" stroke="#000" stroke-width="1.4"/><path d="M9 4.5V9l3.2 2" fill="none" stroke="#000" stroke-width="1.4" stroke-linecap="round"/>' +
  (active ? '<circle cx="20" cy="9" r="1.6" fill="#000"/>' : '');
fs.copyFileSync(path.join(root, 'assets/branding/bolt42.png'), path.join(output, 'DeveloperLogo.png'));
// The manufacturer wordmark is kept only for the branded section and About page.
render(svg(240, 58, logo(0, 0, 240, '#cf291c')), path.join(output, 'RaketaLogo.png'));
for (const active of [false, true]) {
  const name = active ? 'MenuBarIconActive' : 'MenuBarIcon';
  fs.writeFileSync(path.join(output, `${name}.svg`), svg(24, 18, trayArtwork(active)));
  for (const scale of [1, 2, 3]) {
    render(svg(24 * scale, 18 * scale, trayArtwork(active), '0 0 24 18'),
      path.join(output, `${name}${scale === 1 ? '' : `@${scale}x`}.png`));
  }
}

// Review sheet shows real-size menu-bar variants, plus the large app icon.
let preview = '<rect width="760" height="480" fill="#e7e8eb"/>' +
  `<svg x="28" y="32" width="360" height="360" viewBox="0 0 512 512">${appArtwork}</svg>`;
for (const [i, dark] of [false, true].entries()) {
  const y = 85 + i * 115;
  preview += `<rect x="420" y="${y}" width="300" height="64" rx="10" fill="${dark ? '#29292d' : '#fafafa'}"/>`;
  for (const [j, active] of [false, true].entries()) {
    preview += `<svg x="${451 + j * 134}" y="${y + 23}" width="24" height="18" viewBox="0 0 24 18">${trayArtwork(active).replaceAll('#000', `${dark ? '#fff' : '#171719'}`)}</svg>`;
  }
}
for (const [i, size] of [16, 32, 64].entries()) {
  preview += `<svg x="${455 + i * 85}" y="350" width="${size}" height="${size}" viewBox="0 0 512 512">${appArtwork}</svg>`;
}
fs.mkdirSync(path.join(root, 'macos/.build/previews'), { recursive: true });
render(svg(1520, 960, preview, '0 0 760 480'), path.join(root, 'macos/.build/previews/icons.png'));
console.log('Prepared Время app icon from supplied artwork, developer logo, menu-bar templates and Raketa section logo.');
