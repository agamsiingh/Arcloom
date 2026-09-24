import { cpSync, rmSync, mkdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { execSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const outDir = join(root, 'public');

// 1. Bake levels
console.log('Baking levels...');
execSync('node scripts/bake.mjs', { cwd: root, stdio: 'inherit' });

// 2. Prepare clean public directory
console.log('Preparing public/ directory...');
if (existsSync(outDir)) {
  rmSync(outDir, { recursive: true, force: true });
}
mkdirSync(outDir, { recursive: true });

// 3. Copy web assets to public/
const itemsToCopy = [
  'index.html',
  'css',
  'js',
  'assets',
  'manifest.webmanifest',
  'sw.js',
  'privacy',
  'PRIVACY_POLICY.md'
];

for (const item of itemsToCopy) {
  const src = join(root, item);
  const dest = join(outDir, item);
  if (existsSync(src)) {
    cpSync(src, dest, { recursive: true });
    console.log(`Copied ${item} -> public/${item}`);
  }
}

console.log('Build completed successfully! public/ ready for deployment.');
