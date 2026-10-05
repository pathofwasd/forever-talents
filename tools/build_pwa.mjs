import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
const root = path.resolve('web/dist');
async function walk(dir) {
  const files = [];
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...(await walk(p)));
    else if (entry.name !== 'sw.js' && entry.name !== 'pwa-release.json') files.push(p);
  }
  return files.sort();
}
await fs.rm(path.join(root, 'generated/engine.lua'), { force: true });
const files = await walk(root);
const hash = createHash('sha256');
hash.update(await fs.readFile('tools/build_pwa.mjs'));
let bytes = 0;
for (const f of files) {
  const data = await fs.readFile(f);
  hash.update(path.relative(root, f));
  hash.update(data);
  bytes += data.length;
}
const digest = hash.digest('hex'),
  release = JSON.parse(await fs.readFile('web/public/generated/release.json', 'utf8')),
  version = release.version;
const assets = files.map(
  (f) => './' + path.relative(root, f).split(path.sep).map(encodeURIComponent).join('/')
);
const sw = `/* Generated atomic release cache. Source: tools/build_pwa.mjs */
const CACHE='forever-talents-${digest.slice(0, 20)}';
const ASSETS=${JSON.stringify(assets)};
const BASE=new URL('./',self.location.href);
self.addEventListener('install',event=>event.waitUntil((async()=>{
 const cache=await caches.open(CACHE);
 try{await cache.addAll(ASSETS.map(p=>new Request(new URL(p,BASE),{cache:'reload'})));}
 catch(error){await caches.delete(CACHE);throw error;}
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
 // Keep previous immutable assets for clients still finishing an old shell.
 // Updates reload controlled clients before pruning on a later install.
 const previous=(await caches.keys()).filter(n=>n.startsWith('forever-talents-')&&n!==CACHE);
 for(const name of previous.slice(0,-2))await caches.delete(name);
 await self.clients.claim();
})()));
self.addEventListener('message',event=>{if(event.data?.type==='SKIP_WAITING')self.skipWaiting();});
self.addEventListener('fetch',event=>{
 const req=event.request,url=new URL(req.url);
 if(req.method!=='GET'||url.origin!==BASE.origin||!url.pathname.startsWith(BASE.pathname))return;
 event.respondWith((async()=>{
 // All responses are same-origin static files; preview hosts may vary on Origin.
 // Ignore that header so module requests reuse the release's precached bytes.
 const cache=await caches.open(CACHE),hit=await cache.match(req,{ignoreSearch:true,ignoreVary:true});
 if(hit)return hit;
 if(url.pathname.includes('/assets/')||/engine-[a-f0-9]+\\.lua$/.test(url.pathname)){
  for(const name of await caches.keys()){if(name.startsWith('forever-talents-')){const old=await (await caches.open(name)).match(req,{ignoreVary:true});if(old)return old;}}
 }
 if(req.mode==='navigate')return cache.match(new URL('index.html',BASE),{ignoreVary:true});
 return fetch(req);
 })());
});
`;
await fs.writeFile(path.join(root, 'sw.js'), sw);
await fs.writeFile(
  path.join(root, 'pwa-release.json'),
  JSON.stringify(
    { version, sha256: digest, files: files.length, bytes, dataTag: release.dataTag },
    null,
    2
  ) + '\n'
);
await fs.mkdir('dist', { recursive: true });
execFileSync('python3', [
  '-c',
  `from pathlib import Path\nimport zipfile\np=Path('web/dist')\nwith zipfile.ZipFile('dist/ForeverTalents-PWA-${version}.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:\n for f in sorted(p.rglob('*')):\n  if f.is_file(): z.write(f,f.relative_to(p).as_posix())\n`,
]);
console.log(
  `PWA ${version}: ${files.length} precached files, ${(bytes / 1024 / 1024).toFixed(2)} MiB; coherent cache ${digest.slice(0, 12)}. Static ZIP saved in dist.`
);
