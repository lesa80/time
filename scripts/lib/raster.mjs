import assert from 'node:assert/strict';
import { PNG } from 'pngjs';
import { Resvg } from '@resvg/resvg-js';

const previewAngles = { hour: 303.25, minute: 62.4, second: 144 };
const pngURI = data => `data:image/png;base64,${data.toString('base64')}`;
const imageSVG = (body, width, height) => `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg>`;
const embeddedImage = (png, width, height, attrs = '') => `<image width="${width}" height="${height}" href="${pngURI(png)}" ${attrs}/>`;

function rectangle(value, fallback, label) {
  const rect = value ?? fallback;
  assert(Array.isArray(rect) && rect.length === 4 && rect.every(Number.isFinite), `${label} must be [x, y, width, height]`);
  assert(rect[2] > 0 && rect[3] > 0, `${label} must have a positive width and height`);
  return rect;
}

/**
 * Crop and place existing raster material; this function draws no dial artwork.
 * sourceRect is measured in source pixels. targetRect is measured in the final
 * layer canvas and can leave transparent margins around the cropped material.
 */
export function normalizeRaster(png, width, height, options = {}) {
  const source = PNG.sync.read(png);
  const sourceRect = rectangle(options.sourceRect, [0, 0, source.width, source.height], 'sourceRect');
  const targetRect = rectangle(options.targetRect, [0, 0, width, height], 'targetRect');
  const [sx, sy, sw, sh] = sourceRect;
  const [tx, ty, tw, th] = targetRect;
  assert(sx >= 0 && sy >= 0 && sx + sw <= source.width && sy + sh <= source.height, 'sourceRect lies outside the source PNG');
  assert(tx >= 0 && ty >= 0 && tx + tw <= width && ty + th <= height, 'targetRect lies outside the layer canvas');
  const content = `<svg x="${tx}" y="${ty}" width="${tw}" height="${th}" viewBox="${sx} ${sy} ${sw} ${sh}" preserveAspectRatio="none" overflow="hidden">${embeddedImage(png, source.width, source.height)}</svg>`;
  const rendered = new Resvg(imageSVG(content, width, height), { font: { loadSystemFonts: false } }).render().asPng();
  if (!options.circularMask) return rendered;
  const result = PNG.sync.read(rendered);
  const cx = width / 2, cy = height / 2, radius = Math.min(width, height) / 2;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      // One pixel of smooth coverage prevents a jagged circular display edge.
      const coverage = Math.max(0, Math.min(1, radius + .5 - Math.hypot(x + .5 - cx, y + .5 - cy)));
      const offset = (y * width + x) * 4;
      result.data[offset + 3] = Math.round(result.data[offset + 3] * coverage);
      if (!result.data[offset + 3]) result.data.fill(0, offset, offset + 4);
    }
  }
  return PNG.sync.write(result);
}

export function composePreview(layers, resolution, angles = previewAngles, outputWidth = resolution[0]) {
  const body = layers.map(({ name, spec, png, size }) => {
    if (spec.type === 'Hand Res') {
      const [cx, cy] = spec.handResPosition;
      const [px, py] = spec.rotatePoint;
      return embeddedImage(png, size[0], size[1], `x="${cx - px}" y="${cy - py}" transform="rotate(${angles[name] ?? 0} ${cx} ${cy})"`);
    }
    return embeddedImage(png, size[0], size[1], `x="${spec.position[0]}" y="${spec.position[1]}"`);
  }).join('');
  return new Resvg(imageSVG(body, ...resolution), { fitTo: { mode: 'width', value: outputWidth }, font: { loadSystemFonts: false } }).render().asPng();
}

function lanczos(x) {
  const a = Math.abs(x);
  if (a < 1e-8) return 1;
  if (a >= 3) return 0;
  return Math.sin(Math.PI * x) / (Math.PI * x)
    * Math.sin(Math.PI * x / 3) / (Math.PI * x / 3);
}

function weights(center, scale, extent) {
  const filterScale = Math.max(1, scale);
  const result = [];
  let sum = 0;
  for (let i = Math.ceil(center - 3 * filterScale); i <= Math.floor(center + 3 * filterScale); i++) {
    const w = lanczos((i - center) / filterScale);
    if (w === 0) continue;
    sum += w;
    // Pixels outside the source are genuinely transparent padding.
    if (i >= 0 && i < extent) result.push([i, w]);
  }
  return result.map(([i, w]) => [i, w / sum]);
}

export function resample(src, rect, width, height) {
  const [rx, ry, rw, rh] = rect;
  const sx = rw / width;
  const sy = rh / height;
  const xs = Array.from({ length: width }, (_, x) => weights(rx + (x + .5) * sx - .5, sx, src.width));
  const ys = Array.from({ length: height }, (_, y) => weights(ry + (y + .5) * sy - .5, sy, src.height));
  const out = new PNG({ width, height });
  const temporary = new Float64Array(width * src.height * 4);
  for (let y = 0; y < src.height; y++) {
    for (let x = 0; x < width; x++) {
      const di = (y * width + x) * 4;
      for (const [ix, wx] of xs[x]) {
        const si = (y * src.width + ix) * 4;
        const a = src.data[si + 3] / 255;
        temporary[di] += src.data[si] * a * wx;
        temporary[di + 1] += src.data[si + 1] * a * wx;
        temporary[di + 2] += src.data[si + 2] * a * wx;
        temporary[di + 3] += a * wx;
      }
    }
  }
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const accum = [0, 0, 0, 0];
      for (const [iy, wy] of ys[y]) {
        const si = (iy * width + x) * 4;
        for (let c = 0; c < 4; c++) accum[c] += temporary[si + c] * wy;
      }
      const di = (y * width + x) * 4;
      const a = Math.max(0, Math.min(1, accum[3]));
      out.data[di + 3] = Math.round(a * 255);
      if (a > 1 / 510) {
        for (let c = 0; c < 3; c++) out.data[di + c] = Math.round(Math.max(0, Math.min(255, accum[c] / a)));
      }
    }
  }
  return out;
}

function segment(knots, p) {
  let i = 0;
  while (i < knots.length - 2 && p > knots[i + 1][0]) i++;
  const [a, b] = [knots[i], knots[i + 1]];
  const slope = (b[1] - a[1]) / (b[0] - a[0]);
  return { value: a[1] + (p - a[0]) * slope, slope };
}

export function resampleWarped(src, geometry) {
  const [width, height] = geometry.size;
  const [centerX] = geometry.masterPivot;
  const out = new PNG({ width, height });
  for (let y = 0; y < height; y++) {
    const mappedY = segment(geometry.sourceYKnots, y + .5);
    const yWeights = weights(mappedY.value - .5, mappedY.slope, src.height);
    const stepX = 1 / segment(geometry.targetXScaleKnots, y + .5).value;
    for (let x = 0; x < width; x++) {
      const xWeights = weights(centerX + (x + .5 - geometry.pivot[0]) * stepX - .5, stepX, src.width);
      const accum = [0, 0, 0, 0];
      for (const [iy, wy] of yWeights) {
        for (const [ix, wx] of xWeights) {
          const si = (iy * src.width + ix) * 4;
          const a = src.data[si + 3] / 255;
          const w = wy * wx;
          for (let c = 0; c < 3; c++) accum[c] += src.data[si + c] * a * w;
          accum[3] += a * w;
        }
      }
      const di = (y * width + x) * 4;
      const a = Math.max(0, Math.min(1, accum[3]));
      out.data[di + 3] = Math.round(a * 255);
      if (a > 1 / 510) {
        for (let c = 0; c < 3; c++) out.data[di + c] = Math.round(Math.max(0, Math.min(255, accum[c] / a)));
      }
    }
  }
  return out;
}

function rgbToHsv(r, g, b) {
  const v = Math.max(r, g, b), min = Math.min(r, g, b), d = v - min;
  let h = 0;
  if (d > 1e-8) {
    if (v === r) h = ((g - b) / d) % 6;
    else if (v === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h = (h * 60 + 360) % 360;
  }
  return [h, v ? d / v : 0, v];
}

function hsvToRgb(h, s, v) {
  const c = v * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = v - c;
  const sectors = [[c,x,0],[x,c,0],[0,c,x],[0,x,c],[x,0,c],[c,0,x]];
  return sectors[Math.floor(h / 60) % 6].map(n => Math.round((n + m) * 255));
}

export function matchPaintPalette(src, paint) {
  if (!paint) return src;
  const result = new PNG({ width: src.width, height: src.height });
  result.data.set(src.data);
  for (let i = 0; i < src.data.length; i += 4) {
    if (src.data[i + 3] === 0) continue;
    const [h, s, v] = rgbToHsv(src.data[i] / 255, src.data[i + 1] / 255, src.data[i + 2] / 255);
    const red = paint === 'red' && (h < 30 || h > 335);
    const blue = paint === 'blue' && h > 175 && h < 235;
    if (!(red || blue) || s < .2) continue;
    const q = Math.max(0, Math.min(1, (s - .2) / .2));
    const mix = q * q * (3 - 2 * q);
    const unwrappedH = h > 180 ? h - 360 : h;
    const nextH = red ? (3.43 + .25 * (unwrappedH - .5) + 360) % 360 : 204.44 + .4 * (h - 206);
    const nextS = red ? s * .854 : s * .719;
    const nextV = Math.min(1, v * (red ? .804 / .85 : .7451 / .8824));
    const rgb = hsvToRgb(nextH, nextS, nextV);
    for (let c = 0; c < 3; c++) result.data[i + c] = Math.round(src.data[i + c] * (1 - mix) + rgb[c] * mix);
  }
  return result;
}
