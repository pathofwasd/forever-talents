import { defineConfig } from 'vite';
import fs from 'node:fs';
const release = JSON.parse(fs.readFileSync('web/public/generated/release.json', 'utf8'));

export default defineConfig({
  root: 'web',
  define: {
    __ENGINE_FILE__: JSON.stringify(
      'generated/engine-' + release.engineSha256.slice(0, 16) + '.lua'
    ),
  },
  base: './',
  build: { outDir: 'dist', emptyOutDir: true },
  server: { port: 4173, strictPort: true },
  preview: { port: 4173, strictPort: true },
});
