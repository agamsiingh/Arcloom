// Renders the arcloom icon/splash PNGs from the PWA's SVG mark using headless Chrome.
// Usage (from mobile/): node tool/render_icons.mjs
// Requires Google Chrome; set CHROME=/path/to/chrome if it is not in the default location.
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';

const CHROME = process.env.CHROME || [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].find((p) => existsSync(p));
if (!CHROME) throw new Error('Chrome not found; set CHROME env var');

const MARK = `
  <g fill="none" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">
    <path d="M32 30v60" stroke="INK"/>
    <path d="M60 90V44" stroke="#ff8a5c"/>
    <path d="M88 30v34" stroke="INK"/>
    <path d="M24 46h26M70 46h28" stroke="#8fd3c7"/>
    <path d="M24 74h16M50 74h20M80 74h14" stroke="#8fd3c7"/>
  </g>
  <path d="M60 26l-12 16h24z" fill="#ff8a5c"/>`;

// [file, size, svg]
const jobs = [
  // Full-bleed square (iOS masks corners itself; Android legacy icon).
  ['icon.png', 1024, `<rect width="120" height="120" fill="#1d1b2c"/><g transform="translate(14 14) scale(0.7667)">${MARK.replaceAll('INK', '#f4efe6')}</g>`],
  // Adaptive foreground: mark inside the 66% safe zone, transparent background.
  ['icon_foreground.png', 1024, `<g transform="translate(26 26) scale(0.5667)">${MARK.replaceAll('INK', '#f4efe6')}</g>`],
  // Themed (monochrome) icon for Android 13+.
  ['icon_monochrome.png', 1024, `<g transform="translate(26 26) scale(0.5667)">${MARK.replaceAll(/#[0-9a-f]{6}|INK/g, '#ffffff')}</g>`],
  // Splash: rounded tile with the mark.
  ['splash.png', 768, `<rect x="10" y="10" width="100" height="100" rx="28" fill="#1d1b2c"/><g transform="translate(18 18) scale(0.7)">${MARK.replaceAll('INK', '#f4efe6')}</g>`],
  // Android 12+ splash icon (shown inside a circle mask, 2/3 safe area).
  ['splash_android12.png', 1152, `<circle cx="60" cy="60" r="40" fill="#1d1b2c"/><g transform="translate(34 34) scale(0.4333)">${MARK.replaceAll('INK', '#f4efe6')}</g>`],
];

const port = 9500 + Math.floor(Math.random() * 300);
const proc = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${port}`, '--no-first-run', `--user-data-dir=${process.env.TEMP || '/tmp'}/arcloom-icons-${port}`, 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let targets = [];
for (let i = 0; i < 60 && !targets.length; i++) {
  try { targets = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).filter((t) => t.type === 'page'); } catch { /* starting */ }
  await sleep(200);
}
const ws = new WebSocket(targets[0].webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
ws.onmessage = (m) => { const msg = JSON.parse(m.data); pending.get(msg.id)?.(msg); };
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });

mkdirSync('assets/icon', { recursive: true });
for (const [file, size, body] of jobs) {
  await send('Emulation.setDeviceMetricsOverride', { width: size, height: size, deviceScaleFactor: 1, mobile: false });
  await send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
  const html = `<html><body style="margin:0;background:transparent"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="${size}" height="${size}">${body}</svg></body></html>`;
  await send('Page.navigate', { url: 'data:text/html;base64,' + Buffer.from(html).toString('base64') });
  await sleep(400);
  const r = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: size, height: size, scale: 1 } });
  writeFileSync(`assets/icon/${file}`, Buffer.from(r.result.data, 'base64'));
  console.log('wrote assets/icon/' + file);
}
ws.close();
proc.kill();
process.exit(0);
