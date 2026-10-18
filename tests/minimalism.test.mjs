import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import { PNG } from 'pngjs';
import { handAngles, parseTime } from '../time.mjs';

const catalog = JSON.parse(fs.readFileSync(new URL('../themes.json', import.meta.url)));
const registration = JSON.parse(fs.readFileSync(new URL('../assets/minimalism/source/case-registration.json', import.meta.url)));
const read = (id, name) => PNG.sync.read(fs.readFileSync(new URL(`../assets/${id}/${name}.png`, import.meta.url)));
const pixel = (png, x, y) => [...png.data.subarray((Math.floor(y) * png.width + Math.floor(x)) * 4, (Math.floor(y) * png.width + Math.floor(x)) * 4 + 4)];
const specFor = id => JSON.parse(fs.readFileSync(new URL(`../assets/${id}/theme.json`, import.meta.url)));
const whiteBackground = [255, 255, 255, 255];
const ownThemes = [['minimalism', 12, false], ['minimalism-24', 24, false],
  ['minimalism-dark', 12, true], ['minimalism-24-dark', 24, true]];

for (const [id, cycle, dark] of ownThemes) {
  const background = dark ? [0, 0, 0, 255] : whiteBackground;
  const ink = dark ? whiteBackground : [17, 17, 17, 255];
  test(`${id}: flat ${dark ? 'black' : 'white'} 2048px dial with bold contrasting numerals`, () => {
    const dial = read(id, 'dial');
    assert.deepEqual([dial.width, dial.height], [2048, 2048]);
    assert.equal(pixel(dial, 0, 0)[3], 0);
    for (let y = 800; y < 1250; y += 20) for (let x = 800; x < 1250; x += 20) {
      assert.deepEqual(pixel(dial, x, y), background, 'Center must be plain and opaque, without texture or baked hands');
    }
    // A visible gray boundary is essential when the widget sits over white windows.
    for (const [x, y] of [[3, 1024], [2044, 1024], [1024, 3], [1024, 2044]]) {
      const rgba = pixel(dial, x, y);
      assert(rgba[3] > 240 && rgba[0] > 60 && rgba[0] < 180, `Missing outline at ${x},${y}: ${rgba}`);
    }
    if (cycle === 12) assert.deepEqual(pixel(dial, 1024, 60), ink, 'Hour tick must be bold');
    const source = fs.readFileSync(new URL(`../assets/${id}/dial.svg`, import.meta.url), 'utf8');
    assert.match(source, /font-family="Helvetica,Arial,sans-serif"/);
    const text = [...source.matchAll(/font-size="(\d+)"[^>]*>(\d+)<\/text>/g)];
    assert(text.every(m => Number(m[1]) >= (cycle === 12 ? 172 : 154)), 'Numerals must be larger in both themes');
    assert.equal([...source.matchAll(/font-weight="700"/g)].length, text.length, 'Every numeral must use bold type');
    assert.deepEqual(text.map(m => Number(m[2])), cycle === 12 ? Array.from({ length: 12 }, (_, i) => i + 1) : [0, 4, 8, 12, 16, 20]);
    if (cycle === 24) assert.equal(text[0][2], '0', 'Midnight must use a single zero');
    const numeral = [...source.matchAll(/<text[^>]*fill="([^"]+)"/g)];
    assert(numeral.every(m => m[1] === (dark ? '#ffffff' : '#111111')), 'All numerals must contrast with the dial');
    assert.equal(specFor(id).hourCycle, cycle);
  });

  test(`${id}: independent contrasting hands, red seconds, registered to the case aperture`, () => {
    const spec = specFor(id);
    const center = [spec.dialBounds[0] + spec.dialBounds[2] / 2, spec.dialBounds[1] + spec.dialBounds[3] / 2];
    for (const name of ['hour', 'minute', 'second']) {
      const png = read(id, name);
      const expected = name === 'second' ? [220, 38, 38, 255] : ink;
      for (let y = 2; y < png.height - 2; y += 20) {
        assert.deepEqual(pixel(png, png.width / 2, y), expected);
        assert.equal(pixel(png, 0, y)[3], 0);
      }
      const layer = spec.layers.find(l => l.image.endsWith(`/${name}.png`));
      assert.deepEqual(layer.handResPosition, center);
      assert(Math.abs(layer.size[0] / png.width - spec.dialBounds[2] / 2048) < 1e-10);
      assert(Math.abs(layer.size[0] / png.width - layer.size[1] / png.height) < 1e-10);
      assert(layer.rotatePoint[1] > layer.size[1] / 2 && layer.rotatePoint[1] < layer.size[1]);
      if (name !== 'second') {
        const pivotY = layer.rotatePoint[1] / (layer.size[1] / png.height);
        const rearLength = png.height - pivotY;
        assert(rearLength > 76 && rearLength < pivotY * .2, `${name} must have a short visible rear tip`);
        assert.deepEqual(pixel(png, png.width / 2, pivotY + 60), expected, `${name} rear tip must extend past the center cap`);
      }
      if (name === 'hour') {
        for (const x of [8, 64]) assert.deepEqual(pixel(png, x, 300), expected, 'Hour hand must gain width on both sides of its unchanged axis');
      }
    }
  });
}

function atHour(png, hour, radius, tangent = 0) {
  const angle = hour * Math.PI / 12;
  return pixel(png, 1024 + Math.sin(angle) * radius + Math.cos(angle) * tangent,
    1024 - Math.cos(angle) * radius + Math.sin(angle) * tangent);
}

for (const [id, , dark] of ownThemes.filter(([, cycle]) => cycle === 24)) {
  const background = dark ? [0, 0, 0, 255] : whiteBackground;
  test(`${id}: thick markers between numbers and thin marks at remaining hours`, () => {
    const dial = read(id, 'dial');
    const ink = dark ? whiteBackground : [17, 17, 17, 255];
    for (const hour of [2, 6, 10, 14, 18, 22]) {
      assert.deepEqual(atHour(dial, hour, 780, 9), ink, `Missing thick marker at ${hour}`);
      assert.deepEqual(atHour(dial, hour, 825), ink, `Thick marker too short at ${hour}`);
    }
    for (const hour of [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23]) {
      assert.deepEqual(atHour(dial, hour, 780), ink, `Missing thin hour mark at ${hour}`);
      assert.deepEqual(atHour(dial, hour, 780, 9), background, `Hour mark too thick at ${hour}`);
      assert.deepEqual(atHour(dial, hour, 825), background, `Thin hour mark too long at ${hour}`);
    }
  });

  test(`${id}: edge sectors follow exact daily ranges clockwise, including midnight`, () => {
    const dial = read(id, 'dial');
    const red = [220, 38, 38, 255], white = [255, 255, 255, 255], blue = [35, 118, 189, 255];
    for (const [hour, expected] of [[22.1, red], [0, red], [5.9, red], [6.1, white], [9.9, white],
      [10.1, blue], [12, blue], [17.9, blue], [18.1, white], [21.9, white]]) {
      assert.deepEqual(atHour(dial, hour, 969), expected, `Wrong edge color at hour ${hour}`);
      assert.deepEqual(atHour(dial, hour, 945), background, `Sector must be confined to the edge at hour ${hour}`);
    }
  });

  test(`${id}: minute marks sit on sectors with contrasting black or white ink`, () => {
    const dial = read(id, 'dial');
    const black = [17, 17, 17, 255], white = [255, 255, 255, 255];
    for (let minute = 0; minute < 60; minute++) {
      const hour = minute * 24 / 60;
      if ([15, 25, 45, 55].includes(minute)) continue;
      const colored = hour < 6 || hour >= 22 || (hour >= 10 && hour < 18);
      const sectorBackground = colored ? (hour < 6 || hour >= 22 ? [220, 38, 38, 255] : [35, 118, 189, 255]) : white;
      assert.deepEqual(atHour(dial, hour, 990), colored ? white : black, `Wrong minute mark ink: ${minute}`);
      assert.deepEqual(atHour(dial, hour, 990, 9), sectorBackground, `Minute mark must stay thin: ${minute}`);
      assert.deepEqual(atHour(dial, hour, 912), background, `Old minute mark must be absent: ${minute}`);
    }
    // A mark directly on a sector join must contrast with both backgrounds.
    for (const [hour, before, after] of [[6, white, black], [10, black, white], [18, white, black], [22, black, white]]) {
      for (const [offset, expected] of [[-1.5, before], [1.5, after]]) {
        const rgba = atHour(dial, hour, 990, offset);
        assert(rgba.slice(0, 3).every((v, i) => Math.abs(v - expected[i]) < 20), `Boundary ink mismatch at ${hour}: ${rgba}`);
      }
    }
  });

}

test('all four themes use the generated RGBA case unchanged, with a transparent dial aperture and strap holes', () => {
  const sourceBytes = fs.readFileSync(new URL('../assets/minimalism/source/case.png', import.meta.url));
  const source = PNG.sync.read(sourceBytes);
  assert.deepEqual([source.width, source.height], registration.sourceResolution);
  assert.equal(pixel(source, 0, 0)[3], 0);
  assert.equal(pixel(source, 512, 705)[3], 0, 'Case must not include a fixed dial or hands');
  assert(pixel(source, 512, 300)[3] > 240, 'Upper strap must remain opaque');
  assert(pixel(source, 470, 1300)[3] > 240, 'Lower strap must remain opaque');
  assert.equal(pixel(source, 512, 1302)[3], 0, 'Strap perforation must be a real alpha hole');
  for (const [id] of ownThemes) {
    assert.deepEqual(fs.readFileSync(new URL(`../assets/${id}/bezel.png`, import.meta.url)), sourceBytes);
    const spec = specFor(id);
    assert.deepEqual(spec.resolution, registration.canvas);
    assert.deepEqual(spec.dialBounds, registration.dialBounds);
    assert(spec.layers[0].image.endsWith('/bezel.png'));
    const [x, y, w, h] = spec.dialBounds;
    assert.equal(w, h);
    assert.deepEqual([x + w / 2 - registration.sourceOffset[0], y + h / 2 - registration.sourceOffset[1]], [512, 705]);
  }
});

test('Minimalism 24 uses a daily hour revolution while minutes and seconds match the 12-hour theme', () => {
  const twelve = catalog.themes.find(t => t.id === 'minimalism');
  const daily = catalog.themes.find(t => t.id === 'minimalism-24');
  assert(!twelve.brand && !daily.brand);
  assert.equal(twelve.hourCycle, 12);
  assert.equal(daily.hourCycle, 24);
  for (const [time, angle] of [['00:00:00', 0], ['06:00:00', 90], ['12:00:00', 180], ['18:00:00', 270]]) {
    assert.equal(handAngles(parseTime(time), daily.hourCycle).hour, angle);
  }
  const a = handAngles(parseTime('18:23:45'), twelve.hourCycle);
  const b = handAngles(parseTime('18:23:45'), daily.hourCycle);
  assert.equal(a.minute, b.minute);
  assert.equal(a.second, b.second);
  assert.notEqual(a.hour, b.hour);
});

test('provided app icon and neutral tray are separate from the red manufacturer logo', () => {
  const icon = fs.readFileSync(new URL('../assets/icons/app.svg', import.meta.url), 'utf8');
  assert(!icon.includes('#cf291c'));
  const logo = PNG.sync.read(fs.readFileSync(new URL('../assets/icons/RaketaLogo.png', import.meta.url)));
  assert(logo.data.some((v, i) => i % 4 === 0 && v > 150 && logo.data[i + 1] < 80 && logo.data[i + 3] > 200));
  for (const active of ['', 'Active']) for (const scale of [1, 2, 3]) {
    const tray = PNG.sync.read(fs.readFileSync(new URL(`../assets/icons/MenuBarIcon${active}${scale === 1 ? '' : `@${scale}x`}.png`, import.meta.url)));
    assert.deepEqual([tray.width, tray.height], [24 * scale, 18 * scale]);
    assert.equal(tray.data[3], 0);
  }
});
