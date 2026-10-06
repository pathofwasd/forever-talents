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
    run('simpleView', { enabled: true });
    run('state');
    run('skills', { filter: 'now' });
    run('skillLevels', { name: skill.name });
    run('simpleView', { enabled: false });
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
      trainedSkills: { schema: 1, classID: 11, raceID: 4, level: 25, spellIDs: [5185, 5177] },
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
  run('checkTraining', { enabled: true });
  run('trainingReport');
  run('skills', { filter: 'needsTraining' });
  run('level', { level: 29 });
  run('trainingReport');
  run('level', { level: 25 });
  run('checkTraining', { enabled: false });
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
  run('switch', { classID: 1 });
  run('skillLevels', { name: 'Bloodthirst' });
  run('simulate', { name: 'Bloodthirst', rank: 1, state: { attackPower: 1000, crit: 0 } });
  run('switch', { classID: 7 });
  run('skillLevels', { name: 'Lava Burst' });
  run('skillLevels', { name: 'Riptide' });
  run('simulate', { name: 'Riptide', rank: 1, state: { power: 100, crit: 0 } });
  assert.deepEqual(results, native);
  h.close();
});
test('training comparison is opt-in, respects rank boundaries and keeps portable data and local preferences', async () => {
  const h = await harness();
  h.call('switch', { classID: 11 });
  h.call('level', { level: 25 });
  assert.equal(h.call('state').checkTraining, false);
  assert.equal(h.call('trainingReport').enabled, false);
  assert.equal(list(h.call('skills', { filter: 'needsTraining' })).length, 0);
  h.call('checkTraining', { enabled: true });
  assert.equal(h.call('trainingReport').ready, undefined);
  const sheet = h.call('character').sheet;
  sheet.trainedSkills = { schema: 1, classID: 11, raceID: 4, level: 25, spellIDs: [5179, 5188] };
  h.call('characterSave', { sheet });
  const report = h.call('trainingReport');
  assert.equal(report.ready, true);
  assert.equal(report.total, report.new + report.upgrades);
  assert.equal(report.skills.Wrath.status, 'trained');
  assert.equal(report.skills.Wrath.progress, '↑5');
  assert.equal(report.skills['Travel Form'].progress, '↑5');
  assert.equal(report.skills.Moonfire.status, 'new');
  assert.equal(report.skills.Moonfire.progress, '↑0');
  const needed = list(h.call('skills', { filter: 'needsTraining' }));
  assert.equal(needed.length, report.total);
  assert.ok(needed.every((e) => e.comparison.needsTraining && e.skill.kind !== 'racial'));
  h.call('level', { level: 29 });
  assert.equal(h.call('trainingReport').skills.Wrath.progress, '↑1');
  h.call('level', { level: 30 });
  assert.equal(h.call('trainingReport').skills.Wrath.status, 'upgrade');
  assert.equal(h.call('trainingReport').skills.Wrath.progress, '↑0');
  h.call('level', { level: 25 });
  const codes = Object.fromEntries(
    ['build', 'stats', 'character', 'library'].map((kind) => [kind, h.call('export', { kind })])
  );
  h.call('checkTraining', { enabled: false });
  assert.ok(list(h.call('skills', { filter: 'all' })).every((e) => !e.comparison));
  for (const kind of Object.keys(codes)) assert.equal(h.call('export', { kind }), codes[kind]);
  h.call('checkTraining', { enabled: true });
  h.call('simpleView', { enabled: true });
  assert.equal(list(h.call('skills', { filter: 'needsTraining' })).length, report.total);
  const restored = await harness(h.call('database'));
  assert.equal(restored.call('state').checkTraining, true);
  restored.call('checkTraining', { enabled: false });
  restored.call('import', { code: codes.library, includeDrafts: true });
  assert.equal(restored.call('state').checkTraining, false);
  assert.deepEqual(list(restored.call('training').capture.spellIDs), [5179, 5188]);
  restored.close();
  h.close();
});
test('talent first ranks, live progression and removed abilities reach the browser engine', async () => {
  const h = await harness();
  const catalog = h.call('catalog');
  let restored = 0;
  for (const cid of list(catalog.classOrder)) {
    h.call('switch', { classID: cid });
    for (const { skill } of list(h.call('skills', { filter: 'all' }))) {
      const first = list(skill.ranks)[0];
      if (first.label === 'Rank 1' && first.talentGranted) {
        restored++;
        const progression = h.call('skillLevels', { name: skill.name });
        assert.equal(list(progression.ranks)[0].talentGranted, true);
        assert.ok(first.level <= first.toLevel);
      }
    }
  }
  assert.equal(restored, 31);
  h.call('switch', { classID: 11 });
  assert.deepEqual(list(h.call('skills', { query: "Tiger's Fury", filter: 'all' })), []);
  h.call('switch', { classID: 1 });
  const blood = h.call('skill', { name: 'Bloodthirst' });
  assert.equal(list(blood.ranks)[0].spellID, 23881);
  assert.deepEqual(
    list(h.call('skillLevels', { name: 'Bloodthirst' }).ranks).map((r) => r.level),
    [40, 48, 54, 60]
  );
  h.close();
});
test('simple view preserves all portable data, persists locally and follows shared rank records', async () => {
  const h = await harness();
  const catalog = h.call('catalog');
  h.call('save', { title: 'Retained profile' });
  h.call('checkpoint', { title: 'Retained checkpoint' });
  h.call('characterMode', { mode: 'gear' });
  h.call('characterSave', {
    sheet: { mode: 'gear', gear: { head: { name: 'Retained gear', stats: { intellect: 20 } } } },
  });
  const build = h.call('export', { kind: 'build' });
  const character = h.call('export', { kind: 'character' });
  const library = h.call('export', { kind: 'library' });
  const undo = h.call('state').undo;
  h.call('preview', { count: 0 });
  h.call('simpleView', { enabled: true });
  assert.equal(h.call('state').preview, undefined);
  assert.equal(h.call('state').undo, undo);
  assert.equal(h.call('export', { kind: 'build' }), build);
  assert.equal(h.call('export', { kind: 'character' }), character);
  assert.equal(h.call('export', { kind: 'library' }), library);
  const restored = await harness(JSON.parse(JSON.stringify(h.call('database'))));
  assert.equal(restored.init.simpleView, true);
  const imported = await harness();
  imported.call('import', { code: library, includeDrafts: true });
  assert.equal(
    imported.call('state').simpleView,
    false,
    'library sync must keep the recipient view preference'
  );
  for (const cid of list(catalog.classOrder)) {
    restored.call('switch', { classID: cid });
    const entries = list(restored.call('skills', { filter: 'all' }));
    assert.ok(entries.length);
    for (const { skill } of entries) {
      assert.notEqual(skill.kind, 'racial');
      const progression = restored.call('skillLevels', { name: skill.name });
      const levels = list(progression.ranks);
      const live = list(skill.ranks).filter((r) => r.live);
      assert.ok(levels.length <= live.length);
      if (skill.unlock) assert.equal(progression.unlockLevel, 10 + skill.unlock.gate);
      for (const r of levels) {
        assert.equal(r.text, undefined);
        assert.ok(r.level >= skill.firstLevel);
        if (skill.unlock) assert.ok(r.level >= 10 + skill.unlock.gate);
      }
    }
    assert.ok(
      list(restored.call('skills', { filter: 'now' })).every(
        (e) => e.current && e.skill.kind !== 'racial'
      )
    );
  }
  restored.call('simpleView', { enabled: false });
  assert.ok(
    list(restored.call('skills', { filter: 'all' })).some((e) => e.skill.kind === 'racial')
  );
  h.close();
  restored.close();
  imported.close();
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

test('captured trained ranks persist, reject invalid records, and share between character, stats and library formats', async () => {
  const h = await harness();
  const training = { schema: 1, classID: 11, raceID: 4, level: 25, spellIDs: [5185, 5177] };
  h.call('characterSave', {
    sheet: { mode: 'manual', stats: { power: 123 }, trainedSkills: training },
  });
  const rank = h.call('training', { name: 'Wrath' }).rank;
  assert.equal(rank.label, 'Rank 2');
  assert.equal(rank.spellID, 5177);
  h.call('level', { level: 60 });
  const trained = list(h.call('skills', { filter: 'trained' }));
  assert.equal(trained.length, 2);
  assert.equal(trained.find((e) => e.skill.name === 'Wrath').trained.spellID, 5177);
  assert.notEqual(trained.find((e) => e.skill.name === 'Wrath').current.spellID, 5177);
  const unchanged = h.call('export', { kind: 'character' });
  for (const spellIDs of [[5177, 5177], [0], [-1], [1.5], ['5177']]) {
    assert.equal(
      h.raw('characterSave', { sheet: { trainedSkills: { ...training, spellIDs } } }).ok,
      false
    );
    assert.equal(h.call('export', { kind: 'character' }), unchanged);
  }
  assert.equal(
    h.raw('characterSave', { sheet: { trainedSkills: { ...training, classID: 1, raceID: 1 } } }).ok,
    false
  );
  h.call('save', { title: 'Captured character' });
  for (const kind of ['stats', 'character', 'library']) {
    const code = h.call('export', { kind });
    const imported = await harness();
    imported.call('import', { code, includeDrafts: true });
    assert.equal(imported.call('training', { name: 'Wrath' }).rank.spellID, 5177);
    const restored = await harness(imported.call('database'));
    assert.equal(restored.call('training').capture.level, 25);
    imported.close();
    restored.close();
  }
  const assignments = {};
  for (let i = 1; i <= 7; i++)
    assignments['Skill ' + i] = h.call('highlightColor', { assignments });
  assert.deepEqual(Object.values(assignments), [1, 2, 3, 4, 5, 6, 1]);
  const related = [{ id: 123 }];
  assert.deepEqual(
    h.call('highlights', {
      selections: [
        { skill: { related }, color: 2 },
        { skill: { related }, color: 5 },
      ],
    }),
    { 123: { 2: true, 5: true } }
  );
  h.close();
});
