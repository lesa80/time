import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const scratch = path.join(root, 'macos/.build');
export const appName = 'Время';
export const executableName = 'Vremya';
export const iconName = 'Vremya';
export const archiveName = `${appName} macOS.zip`;
export const run = (command, args, options = {}) => execFileSync(command, args, { cwd: root, stdio: 'inherit', ...options });
export const coreSources = ['Localization.swift', 'Clock.swift', 'Chronograph.swift', 'GShock.swift', 'WindowGeometry.swift', 'LaunchOptions.swift'].map(f => `macos/Sources/${f}`);
export const appSources = [...coreSources, ...['Renderer.swift', 'ClockView.swift', 'App.swift', 'GShockUI.swift', 'About.swift'].map(f => `macos/Sources/${f}`)];
export function compilerFlags() {
  if (process.platform !== 'darwin') throw new Error('Native builds require macOS and Command Line Tools.');
  const sdk = execFileSync('xcrun', ['--show-sdk-path'], { encoding: 'utf8' }).trim();
  return ['-O', '-swift-version', '6', '-warnings-as-errors', '-sdk', sdk,
    '-module-cache-path', path.join(scratch, 'module-cache')];
}
