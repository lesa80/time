/** Parse a 24-hour input value without silently accepting an invalid clock. */
export function parseTime(value) {
  const match = /^(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(value);
  if (!match) return null;
  const [, h, m, s = '00'] = match;
  const time = { hours: Number(h), minutes: Number(m), seconds: Number(s), milliseconds: 0 };
  if (time.hours > 23 || time.minutes > 59 || time.seconds > 59) return null;
  return time;
}

export function formatTime({ hours, minutes, seconds }) {
  return [hours, minutes, Math.floor(seconds)].map(value => String(value).padStart(2, '0')).join(':');
}

export function handAngles({ hours, minutes, seconds, milliseconds = 0 }, hourCycle = 24, direction = 1) {
  if (![12, 24].includes(hourCycle)) throw new RangeError('hourCycle must be 12 or 24');
  if (![1, -1].includes(direction)) throw new RangeError('direction must be 1 or -1');
  const preciseSeconds = seconds + milliseconds / 1000;
  const preciseMinutes = minutes + preciseSeconds / 60;
  return {
    hour: (hours % hourCycle + preciseMinutes / 60) * 360 / hourCycle * direction,
    minute: preciseMinutes * 6 * direction,
    second: preciseSeconds * 6 * direction,
  };
}

export function localTime(date = new Date()) {
  return {
    hours: date.getHours(),
    minutes: date.getMinutes(),
    seconds: date.getSeconds(),
    milliseconds: date.getMilliseconds(),
    day: date.getDate(),
    month: date.getMonth() + 1,
    weekday: date.getDay() + 1,
  };
}

/** The raster atlas uses fixed two-character fields, independent of UI language. */
export function displayText(field, reading) {
  const two = value => String(Math.floor(value)).padStart(2, '0');
  switch (field) {
    case 'hours': return two(reading.hours);
    case 'hours12': return String(reading.hours % 12 || 12).padStart(2, ' ');
    case 'colon': return ':';
    case 'minutes': return two(reading.minutes);
    case 'seconds': return two(reading.seconds);
    case 'day': return two(reading.day ?? 1);
    case 'month': return two(reading.month ?? 1);
    case 'date': return String(reading.day ?? 1).padStart(2, ' ');
    case 'weekday': return ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'][(reading.weekday ?? 1) - 1];
    case 'format': return '24H';
    case 'indicators': return ' '.repeat(13);
    case 'separator': return '-';
    default: throw new RangeError(`Unknown display field: ${field}`);
  }
}
