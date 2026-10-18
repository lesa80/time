import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTime, formatTime, handAngles } from '../time.mjs';

test('the hour hand completes one revolution per 24 hours', () => {
  assert.deepEqual(handAngles(parseTime('00:00:00')), { hour: 0, minute: 0, second: 0 });
  assert.deepEqual(handAngles(parseTime('12:00:00')), { hour: 180, minute: 0, second: 0 });
  assert.deepEqual(handAngles(parseTime('18:00:00')), { hour: 270, minute: 0, second: 0 });
});

test('all three hands include the smaller units of the selected time', () => {
  const angles = handAngles(parseTime('20:10:24'));
  assert.ok(Math.abs(angles.hour - 302.6) < 1e-8);
  assert.ok(Math.abs(angles.minute - 62.4) < 1e-8);
  assert.equal(angles.second, 144);
  assert.equal(handAngles({ hours: 0, minutes: 0, seconds: 0, milliseconds: 500 }).second, 3);
});

test('24-hour input is parsed strictly and formatted with seconds', () => {
  assert.equal(formatTime(parseTime('00:00')), '00:00:00');
  assert.equal(formatTime(parseTime('23:59:59')), '23:59:59');
  for (const value of ['', '24:00:00', '20:60:00', '20:00:60', '-1:00:00', '1:00', '12:00:00bad']) {
    assert.equal(parseTime(value), null, value);
  }
});

test('Minimalism supports distinct 12-hour and 24-hour cycles', () => {
  assert.equal(handAngles(parseTime('12:00:00'), 12).hour, 0);
  assert.equal(handAngles(parseTime('18:00:00'), 12).hour, 180);
  assert.equal(handAngles(parseTime('18:00:00'), 24).hour, 270);
  assert(Math.abs(handAngles(parseTime('06:07:50'), 12).hour - 183.91666666666666) < 1e-8);
  assert.equal(handAngles(parseTime('06:07:50'), 12).minute, 47);
  assert.throws(() => handAngles(parseTime('00:00:00'), 0), RangeError);
});
