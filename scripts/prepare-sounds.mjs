import fs from 'node:fs';
import path from 'node:path';
import { root } from './lib/macos.mjs';

// An original piezo-style button tone, synthesized without recorded samples.
const sampleRate = 44_100;
const durationSeconds = 0.080;
const frequency = 4_096;
const peakAmplitude = 0.18;
const thirdHarmonic = 0.08;
const fadeSeconds = 0.002;
const sampleCount = Math.round(sampleRate * durationSeconds);
const fadeSamples = Math.round(sampleRate * fadeSeconds);
const pcm = Buffer.alloc(sampleCount * 2);

for (let index = 0; index < sampleCount; index++) {
  const phase = 2 * Math.PI * frequency * index / sampleRate;
  const carrier = (Math.sin(phase) + thirdHarmonic * Math.sin(3 * phase)) / (1 + thirdHarmonic);
  const edgeDistance = Math.min(index, sampleCount - 1 - index);
  const fade = edgeDistance < fadeSamples
    ? 0.5 - 0.5 * Math.cos(Math.PI * edgeDistance / fadeSamples)
    : 1;
  const decay = 1 - 0.28 * index / (sampleCount - 1);
  const sample = Math.round(carrier * peakAmplitude * fade * decay * 32_767);
  pcm.writeInt16LE(sample, index * 2);
}

const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + pcm.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20); // Linear PCM.
header.writeUInt16LE(1, 22); // Mono.
header.writeUInt32LE(sampleRate, 24);
header.writeUInt32LE(sampleRate * 2, 28);
header.writeUInt16LE(2, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(pcm.length, 40);

const output = path.join(root, 'assets/sounds/gshock-button.wav');
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, Buffer.concat([header, pcm]));
console.log(`Prepared original button tone: ${output} (${durationSeconds * 1000} ms, ${frequency} Hz).`);
