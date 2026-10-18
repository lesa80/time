import { parseTime, formatTime, handAngles, localTime } from './time.mjs';
import themeDefinitions from './themes-data.mjs';

let theme;
let photoTime;
let photoAngles;
const hands = Object.fromEntries(['hour', 'minute', 'second'].map(name => [name, document.getElementById(name)]));
const dial = document.getElementById('dial');
const digitalTime = document.getElementById('digital-time');
const modeDescription = document.getElementById('mode-description');
const input = document.getElementById('time-input');
const inputContainer = document.getElementById('custom-time');
const inputError = document.getElementById('time-error');
const modeButtons = [...document.querySelectorAll('[data-mode]')];
const descriptions = {
  photo: 'Положение стрелок как на фото',
  live: 'Местное время вашего устройства',
  custom: 'Выбранное время',
};
let mode = 'photo';
let customTime = photoTime;
let animationId;
let lastLabel = '';
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const themeSelect = document.getElementById('theme-select');
const bezelButton = document.getElementById('toggle-bezel');
let showFullWatch = true;

function layoutTheme() {
  const spec = theme.spec;
  const viewport = showFullWatch ? [0, 0, ...spec.resolution] : spec.dialBounds;
  dial.style.aspectRatio = `${viewport[2]} / ${viewport[3]}`;
  dial.classList.toggle('without-bezel', !showFullWatch);
  dial.classList.toggle('rectangular', spec.dialShape === 'rectangle');
  for (const image of dial.querySelectorAll('img')) image.style.display = 'none';
  for (const layer of spec.layers) {
    const name = layer.image.split('/').at(-1).replace('.png', '');
    const image = dial.querySelector(name === 'dial' || name === 'bezel' ? `.${name}-background` : `.${name}`);
    const size = layer.size ?? spec.resolution;
    const position = layer.handResPosition ? layer.handResPosition.map((n, i) => n - layer.rotatePoint[i]) : layer.position;
    image.src = layer.image;
    image.style.inset = 'auto';
    image.style.width = `${size[0] / viewport[2] * 100}%`;
    image.style.left = `${(position[0] - viewport[0]) / viewport[2] * 100}%`;
    image.style.top = `${(position[1] - viewport[1]) / viewport[3] * 100}%`;
    image.style.display = name === 'bezel' && !showFullWatch ? 'none' : 'block';
    if (layer.rotatePoint) image.style.transformOrigin = `${layer.rotatePoint[0] / size[0] * 100}% ${layer.rotatePoint[1] / size[1] * 100}%`;
  }
  const hasBezel = spec.layers.some(layer => layer.image.endsWith('/bezel.png'));
  bezelButton.disabled = !hasBezel;
  bezelButton.setAttribute('aria-pressed', String(hasBezel && showFullWatch));
}

function selectTheme(id) {
  stopTick();
  theme = themeDefinitions.themes.find(t => t.id === id) ?? themeDefinitions.themes.find(t => t.id === themeDefinitions.defaultTheme);
  photoTime = parseTime(theme.referenceTime);
  photoAngles = theme.referenceAngles;
  customTime ??= photoTime;
  input.value = formatTime(customTime);
  themeSelect.value = theme.id;
  document.getElementById('theme-name').textContent = theme.title;
  document.getElementById('theme-label').textContent = `${theme.title} · РАСТР 2048 × 2048`;
  document.getElementById('theme-description').textContent = `${theme.hourCycle}-часовой циферблат${theme.direction === -1 ? ' · обратный ход стрелок' : ''}. ${theme.brand === 'raketa' ? 'Корпус и ремешок из референса.' : 'Однотонный фон с тонким контуром, крупные цифры, прямые стрелки. Собственный корпус и матовый ремешок.'}`;
  document.getElementById('clock-note').textContent = `Локальное превью · полный оборот часовой стрелки за ${theme.hourCycle} часов`;
  layoutTheme();
  render();

  if (mode === 'live') tick();
}

function render() {
  const time = mode === 'live' ? localTime() : mode === 'custom' ? customTime : photoTime;
  const angles = mode === 'photo' ? photoAngles : handAngles(time, theme.hourCycle, theme.direction ?? 1);
  for (const [name, angle] of Object.entries(angles)) hands[name].style.transform = `rotate(${angle}deg)`;
  const label = formatTime(time);
  digitalTime.value = label;
  digitalTime.textContent = label;
  if (`${mode}:${label}` !== lastLabel) {
    dial.setAttribute('aria-label', `Циферблат «${theme.title}», ${label}. ${descriptions[mode]}.`);
    lastLabel = `${mode}:${label}`;
  }
}

function tick() {
  if (mode !== 'live' || document.hidden) return;
  render();
  animationId = reducedMotion.matches ? window.setTimeout(tick, 1000) : window.requestAnimationFrame(tick);
}

function stopTick() {
  window.cancelAnimationFrame(animationId);
  window.clearTimeout(animationId);
}

function setMode(nextMode) {
  stopTick();
  mode = nextMode;
  for (const button of modeButtons) button.setAttribute('aria-pressed', String(button.dataset.mode === mode));
  modeDescription.textContent = descriptions[mode];
  inputContainer.hidden = mode !== 'custom';
  render();
  if (mode === 'live') tick();
  if (mode === 'custom') input.focus();
}

for (const button of modeButtons) button.addEventListener('click', () => setMode(button.dataset.mode));
bezelButton.addEventListener('click', () => {
  showFullWatch = !showFullWatch;
  layoutTheme();
});
themeSelect.addEventListener('change', () => {
  selectTheme(themeSelect.value);
  try { localStorage.setItem('raketa.theme', theme.id); } catch { /* Optional preference storage. */ }
});
input.addEventListener('input', () => {
  const nextTime = parseTime(input.value);
  inputError.textContent = nextTime ? '' : 'Укажите время от 00:00:00 до 23:59:59.';
  input.setAttribute('aria-invalid', String(!nextTime));
  if (nextTime) {
    customTime = nextTime;
    render();
  }
});
document.addEventListener('visibilitychange', () => {
  stopTick();
  if (!document.hidden && mode === 'live') tick();
});
reducedMotion.addEventListener('change', () => {
  stopTick();
  if (mode === 'live') tick();
});

const raketaGroup = document.createElement('optgroup');
raketaGroup.label = 'Ракета';
const ownOptions = [];
for (const item of themeDefinitions.themes) {
  const option = document.createElement('option');
  option.value = item.id;
  option.textContent = item.title;
  if (item.brand === 'raketa') raketaGroup.append(option);
  else ownOptions.push(option);
}
themeSelect.replaceChildren(...ownOptions, raketaGroup);
let savedTheme;
try { savedTheme = localStorage.getItem('raketa.theme'); } catch { /* File previews may restrict storage. */ }
selectTheme(savedTheme ?? themeDefinitions.defaultTheme);
