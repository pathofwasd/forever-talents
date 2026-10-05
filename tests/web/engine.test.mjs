import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { LuaFactory } from 'wasmoon';
const script = fs.readFileSync('web/public/generated/engine.lua', 'utf8');
const list = (v) => Object.values(v || {});
async function harness(saved = {}) {
  const lua = await new LuaFactory().createEngine({ enableProxy: false });
  await lua.doString(script);
  await lua.doString('time=function()return 1700000000 end');
  const invoke = lua.global.get('webCall');
  const raw = (n, p = {}) => JSON.parse(invoke(n, p));
  const call = (n, p = {}) => {
    const r = raw(n, p);
    assert.equal(r.ok, true, r.error);
    return r.value;
  };
  const init = JSON.parse(lua.global.get('webInit')(saved));
  return { lua, call, raw, init, close: () => lua.global.close() };
}
test('Lua 5.4/WASM and actual addon Lua 5.1 produce identical operations, codecs, graph and numerical estimates', async () => {
  const native = execFileSync('lua5.1', ['tests/web/parity.lua'], { encoding: 'utf8' })
    .trim()
    .split('\n')
    .map(JSON.parse);
  const h = await harness();
  const catalog = h.call('catalog');
  const results = [];
  const run = (n, p = {}) => results.push(h.raw(n, p));
  for (const cid of list(catalog.classOrder)) {
    run('switch', { classID: cid });
    run('auto', { enabled: true });
    for (const tree of list(catalog.classes[cid].trees))
      run('add', { id: list(tree.talents)[0].id, fill: true });
    run('save', { title: 'Parity ' + catalog.classes[cid].name });
    run('checkpoint', { title: 'Branch fixture' });
    run('state');
    run('export', { kind: 'build' });
    run('scenario', {
      state: {
        power: 175.25,
        crit: 14.5,
        attackPower: 260,
        weaponMin: 90,
        weaponMax: 120,
        bleeding: true,
        coefficient: 57.125,
      },
      name: 'Wrath',
      manual: true,
    });
    run('export', { kind: 'stats' });
    run('export', { kind: 'character' });
    const skill = list(h.call('skills', { filter: 'all' })).find(
      (e) => e.skill.kind !== 'racial'
    ).skill;
    run('simulate', {
      name: skill.name,
      rank: 1,
      state: { power: 75, crit: 13, hit: 90, reduction: 10 },
    });
    run('preview', { count: 3 });
    run('export', { kind: 'character' });
    run('preview', {});
  }
  run('switch', { classID: 11 });
  run('auto', { enabled: false });
  run('level', { level: 25 });
  run('characterMode', { mode: 'gear' });
  run('characterSave', {
    sheet: {
      schema: 1,
      mode: 'gear',
      name: 'Shared character',
      form: 'cat',
      weaponType: 'none',
      stats: { power: 123.25, hit: 93 },
      gear: {
        mainHand: {
          name: 'Dagger',
          stats: { strength: 10, intellect: 23, attackPower: 14 },
          low: 10,
          high: 20,
          speed: 1.8,
          weaponType: 'dagger',
        },
      },
    },
  });
  run('character');
  run('export', { kind: 'stats' });
  run('export', { kind: 'character' });
  run('statsForSkill', { name: 'Wrath', rank: 4, overrides: { coefficient: 75 } });
  run('simulate', { name: 'Wrath', rank: 4, overrides: { power: 900, crit: 13 } });
  run('simulate', {
    name: 'Wrath',
    rank: 4,
    overrides: { power: 900, crit: 13 },
    withTalents: false,
  });
  run('character');
  run('export', { kind: 'library' });
  run('simulate', { name: 'Wrath', rank: 4, overrides: { attackPower: 1000, apCoefficient: 20 } });
  run('export', {
    kind: 'stats',
    skillName: 'Wrath',
    state: { attackPower: 1000, apCoefficient: 20, dotAPCoefficient: 30 },
  });
  assert.deepEqual(results, native);
  h.close();
});
test('all classes enforce budgets, row gates, prerequisites and legal ordered edits in the browser engine', async () => {
  const h = await harness(),
    catalog = h.call('catalog');
  for (const cid of list(catalog.classOrder)) {
    h.call('switch', { classID: cid });
    h.call('auto', { enabled: true });
    const nodes = list(catalog.classes[cid].trees).flatMap((t) => list(t.talents));
    const gated = nodes.find((t) => t.gate >= 20);
    assert.equal(h.raw('add', { id: gated.id }).ok, false);
    for (let step = 0; step < 51; step++) {
      const access = h.call('talents'),
        t = nodes.find((t) => access[t.id].available);
      assert.ok(t);
      h.call('add', { id: t.id });
      const s = h.call('state');
      assert.equal(s.build.level, step + 10);
      assert.equal(list(s.build.order).length, step + 1);
    }
    assert.equal(h.raw('add', { id: nodes[0].id }).ok, false);
    const code = h.call('export', { kind: 'build' });
    assert.equal(list(h.call('decode', { code }).build.order).length, 51);
    assert.equal(h.raw('import', { code: code + '!' }).ok, false);
    h.call('undo');
    assert.equal(h.call('state').build.level, 59);
    h.call('redo');
    assert.equal(h.call('state').build.level, 60);
    h.call('preview', { count: 0 });
    const empty = h.call('decode', { code: h.call('export', { kind: 'character' }) });
    assert.equal(empty.build.level, 1);
    h.call('preview', {});
  }
  h.close();
});
test('portable library merges all branches, deduplicates and converts saved numeric maps without losing node 1', async () => {
  const source = await harness();
  source.call('save', { title: 'Portable' });
  source.call('checkpoint', { title: 'Left' });
  source.call('load', { profileID: 'p1', nodeID: 1 });
  source.call('checkpoint', { title: 'Right' });
  const code = source.call('export', { kind: 'library' });
  const dest = await harness();
  assert.equal(dest.call('import', { code, includeDrafts: true }).added, 1);
  assert.equal(dest.call('import', { code }).skipped, 1);
  const db = JSON.parse(JSON.stringify(dest.call('database')));
  const restored = await harness(db);
  const s = restored.call('state');
  assert.equal(s.profiles.p1.nodes[1].title, 'Starting build');
  assert.equal(s.profiles.p1.nodes[2].parent, 1);
  assert.equal(s.profiles.p1.nodes[3].parent, 1);
  assert.equal(s.activeNode, 3);
  restored.call('deleteNode', { profileID: 'p1', nodeID: 1 });
  restored.call('undo');
  assert.equal(restored.call('state').activeProfile, undefined);
  source.close();
  dest.close();
  restored.close();
});
test('stats-only import keeps talent draft, rejects corruption, preserves newer schemas and whitelists operations', async () => {
  const h = await harness();
  const stats = h.call('export', {
    kind: 'stats',
    state: { power: 100.125, crit: 23, coefficient: 57.5 },
    skillName: 'Wrath',
  });
  const before = h.call('state').build;
  h.call('import', { code: stats });
  assert.deepEqual(h.call('state').build, before);
  assert.equal(h.call('state').scenario.power, 100.125);
  assert.equal(h.raw('decode', { code: stats.slice(0, -1) + '0' }).ok, false);
  assert.equal(h.raw('os.execute', { code: 'anything' }).ok, false);
  const newer = await harness({ schema: 2, profiles: { future: 'preserved' } });
  assert.equal(newer.init.readOnly, true);
  assert.equal(newer.raw('save', { title: 'No' }).ok, false);
  h.close();
  newer.close();
});
