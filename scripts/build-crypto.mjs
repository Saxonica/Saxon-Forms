/**
 * Bundles @noble/hashes into a standalone IIFE for browser use.
 * Produces builds/saxon-forms-crypto.js exposing window.nobleHashes.
 * 
 * Usage: node scripts/build-crypto.mjs
 */
import { build } from 'vite';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');

await build({
  configFile: false,
  build: {
    lib: {
      entry: resolve(root, 'scripts/crypto-entry.mjs'),
      name: 'nobleHashes',
      formats: ['iife'],
      fileName: () => 'saxon-forms-crypto.js',
    },
    outDir: resolve(root, 'builds'),
    emptyOutDir: false,
    minify: true,
    rollupOptions: {
      output: { extend: true },
    },
  },
});
console.log('Built builds/saxon-forms-crypto.js');
