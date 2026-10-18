import fs from 'node:fs';

// Embed the supplied pixels so the original lettering and red 42 keep their
// contours. Crop the slogan out without redrawing or typesetting the wordmark.
const wordmark = fs.readFileSync(new URL('../../assets/branding/bolt42.png', import.meta.url)).toString('base64');

export function bolt42DialBranding({ ink, dark }) {
  // Solve the resting angle from the lower head facet and the end chamfer.
  // Their outlines touch the same horizontal surface, without floating or
  // passing through it. Include the 12px outline's miter at each chamfer.
  const contourWidth = 12, halfContour = contourWidth / 2;
  const headSupport = [-150 + halfContour * (Math.SQRT2 - 1), 90 + halfContour];
  const tipSupport = [198 + halfContour * (Math.hypot(12, 13) - 12) / 13, 51 + halfContour];
  const tilt = Math.atan2(headSupport[1] - tipSupport[1], tipSupport[0] - headSupport[0]);
  const groundY = headSupport[0] * Math.sin(tilt) + headSupport[1] * Math.cos(tilt) + halfContour;
  // Short 45-degree strokes begin on the lower edge of the ground line.
  const hatch = Array.from({ length: 14 }, (_, i) =>
    `<path d="M${-250 + i * 40} ${groundY + halfContour} l-24 24"/>`).join('');
  const bolt = `<g transform="translate(1024 650)" fill="none" stroke="${ink}" stroke-linejoin="miter" stroke-linecap="butt">` +
    `<g stroke-width="${halfContour}">${hatch}</g>` +
    `<path d="M-280 ${groundY} H280" stroke-width="${contourWidth}"/>` +
    `<g transform="rotate(${tilt * 180 / Math.PI})" stroke-width="${contourWidth}">` +
    '<path d="M-220-85 L-215-90 H-150 L-145-85 V85 L-150 90 H-215 L-220 85 Z"/>' +
    '<path d="M-145-51 H198 L210-38 V38 L198 51 H-145"/>' +
    '<g stroke-width="8">' + [-105, -63, -21, 21, 63, 105, 147].map(x => `<path d="M${x}-51 l28 102"/>`).join('') +
    '</g></g></g>';
  // The lower leg of the large 4 extends below the letters. Keep that leg while
  // excluding the separate slogan beneath БОЛТ; the source image stays intact.
  const crop = '<clipPath id="bolt42-wordmark"><path d="M100 145 H2065 V480 H1695 V595 H1545 V480 H100 Z"/></clipPath>';
  // On black dials, turn the dark letters white while retaining the red accent
  // and the source alpha. Work in sRGB to preserve the supplied red hue.
  const adaptation = dark ? '<filter id="bolt42-on-dark" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB"><feColorMatrix values="0 0 0 0 1 -1 1 0 0 1 -1 0 1 0 1 0 0 0 1 0"/></filter>' : '';
  const logo = `<svg x="724" y="1270" width="600" height="${600 * 450 / 1965}" viewBox="100 145 1965 450" overflow="hidden">` +
    `<defs>${crop}${adaptation}</defs><g clip-path="url(#bolt42-wordmark)">` +
    `<image width="2170" height="725" href="data:image/png;base64,${wordmark}"${dark ? ' filter="url(#bolt42-on-dark)"' : ''}/></g></svg>`;
  return bolt + logo;
}
