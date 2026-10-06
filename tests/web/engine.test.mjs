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
  const native = execFileSync('lua5.1', ['tests/web/parity.lua'], {
    encoding: 'utf8',
    maxBuffer: 8 * 1024 * 1024,
  })
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
    run('remove', { id: list(list(catalog.classes[cid].trees)[0].talents)[0].id });
    run('export', { kind: 'profile' });
    run('updateCheckpoint');
    run('export', { kind: 'profile' });
    run('state');
    run('export', { kind: 'build' });
    run('export', { kind: 'link' });
    run('decode', { code: h.call('export', { kind: 'link' }), buildOnly: true });
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
  run('switch', { classID: 2 });
  run('auto', { enabled: false });
  for (const level of [49, 50, 53, 54, 60]) {
    run('level', { level });
    run('skills', { query: 'Holy Light', includeRacials: false });
  }
  run('simulate', { name: 'Holy Light', rank: 7, state: { power: 100, crit: 0 } });
  for (const classID of [4, 5, 8, 9]) {
    run('switch', { classID });
    run('level', { level: 60 });
    run('skills', { filter: 'all' });
  }
  run('switch', { classID: 8 });
  run('race', { raceID: 7 });
  run('characterSave', {
    sheet: {
      schema: 1,
      mode: 'gear',
      name: 'Alias capture',
      trainedSkills: { schema: 1, classID: 8, raceID: 7, level: 60, spellIDs: [28271] },
      stats: {},
      gear: {},
    },
  });
  run('training', { name: 'Polymorph' });
  run('checkTraining', { enabled: true });
  run('trainingReport');
  run('export', { kind: 'character' });
  run('export', { kind: 'library' });
  run('simulate', { name: 'Fireball', rank: 12, state: { power: 100, crit: 0, cooldowns: true } });
  const fixture = execFileSync('lua5.1', ['tests/fixtures/mage_fire.lua'], {
    encoding: 'utf8',
  }).trim();
  run('import', { code: fixture });
  run('auto', { enabled: true });
  run('save', { title: 'Removal parity' });
  run('checkpoint', { title: 'Frozen allocation' });
  run('export', { kind: 'build' });
  run('remove', { id: 105796 });
  run('state');
  for (const kind of ['build', 'stats', 'character', 'library']) run('export', { kind });
  run('undo');
  run('export', { kind: 'build' });
  run('redo');
  run('export', { kind: 'build' });
  run('remove', { id: 105796 });
  run('state');
  run('remove', { id: 105796 });
  run('export', { kind: 'build' });
  run('remove', { id: 105790 });
  run('export', { kind: 'library' });
  const profileID = h.call('state').activeProfile;
  run('load', { profileID, nodeID: 1 });
  run('state');
  run('export', { kind: 'library' });
  run('undo');
  run('export', { kind: 'build' });
  run('redo');
  run('load', { profileID, nodeID: 3 });
  run('export', { kind: 'character' });
  run('export', { kind: 'library' });
  run('remove', { id: 105776 });
  run('export', { kind: 'profile', profileID });
  run('export', { kind: 'profileLink', profileID });
  run('decode', { code: h.call('export', { kind: 'profileLink', profileID }), profileOnly: true });
  run('import', { code: h.call('export', { kind: 'profileLink', profileID }), profileOnly: true });
  run('state');
  run('export', { kind: 'build' });
  run('export', { kind: 'library' });
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
test('inline skill progression shows the next displayed rank or maximum independently of comparison', async () => {
  const h = await harness();
  h.call('switch', { classID: 3 });
  h.call('level', { level: 8 });
  const skill = (name) =>
    list(h.call('skills', { query: name })).find((e) => e.skill.name === name);
  assert.equal(skill('Arcane Shot').progression.label, 'Next rank 2 · level 12');
  assert.equal(skill('Call Pet').progression.label, 'Unlock · level 10');
  assert.equal(skill('Concussive Shot').progression.label, 'No rank upgrades');
  assert.equal(skill('Aspect of the Hawk').progression.label, 'Unlock rank 1 · level 10');
  h.call('level', { level: 58 });
  assert.equal(skill("Hunter's Mark").progression.label, 'Max rank 4');
  h.call('simpleView', { enabled: true });
  assert.equal(skill("Hunter's Mark").progression.label, 'Max rank 4');
  h.call('level', { level: 20 });
  const sheet = h.call('character').sheet;
  sheet.trainedSkills = {
    schema: 1,
    classID: 3,
    raceID: h.call('state').build.raceID,
    level: 8,
    spellIDs: [3044],
  };
  h.call('characterSave', { sheet });
  const code = h.call('export', { kind: 'library' });
  assert.equal(skill('Arcane Shot').progression.label, 'Next rank 2 · level 12');
  h.call('checkTraining', { enabled: true });
  assert.equal(skill('Arcane Shot').progression.label, 'Next rank 4 · level 28');
  assert.equal(skill('Arcane Shot').comparison.progress, '↑0');
  assert.equal(h.call('export', { kind: 'library' }), code);
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
  assert.equal(restored, 32);
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
test('legal talent removal repairs leveling order and preserves checkpoints and exact undo', async () => {
  const fixture = execFileSync('lua5.1', ['tests/fixtures/mage_fire.lua'], {
    encoding: 'utf8',
  }).trim();
  const h = await harness();
  h.call('import', { code: fixture });
  h.call('auto', { enabled: true });
  h.call('save', { title: 'Fire checkpoint' });
  h.call('checkpoint', { title: 'Before editing' });
  const before = h.call('export', { kind: 'build' });
  const frozenProfiles = h.call('state').profiles;
  const frozen = JSON.stringify(frozenProfiles);
  h.call('remove', { id: 105796 });
  const after = h.call('export', { kind: 'build' });
  assert.equal(h.call('state').counts[105796], 2);
  assert.equal(h.call('state').treeCounts[41], 32);
  assert.equal(h.call('state').treeCounts[61], 8);
  assert.equal(h.call('state').viewLevel, 49);
  assert.match(h.call('state').message, /Leveling order adjusted/);
  assert.equal(JSON.stringify(h.call('state').profiles), frozen);
  assert.equal(h.call('decode', { code: after }).kind, 'build');
  h.call('undo');
  assert.equal(h.call('export', { kind: 'build' }), before);
  h.call('redo');
  assert.equal(h.call('export', { kind: 'build' }), after);
  h.call('remove', { id: 105796 });
  assert.equal(h.call('state').counts[105796], 1);
  const intactBuild = h.call('export', { kind: 'build' });
  const intact = h.call('export', { kind: 'library' });
  for (const payload of [{ id: 105796 }, { id: 105796, all: true }, { id: 105790 }]) {
    assert.equal(h.raw('remove', payload).ok, false);
    assert.equal(h.call('export', { kind: 'library' }), intact);
  }
  h.call('remove', { id: 105776 }); // Ordinary Frost removal requires no reordering.
  assert.equal(h.call('state').message, '');
  const db = h.call('database');
  const restored = await harness(JSON.parse(JSON.stringify(db)));
  const normalized = h.call('decode', { code: h.call('export', { kind: 'library' }) }).database;
  assert.deepEqual(restored.call('database').drafts, normalized.drafts);
  assert.deepEqual(restored.call('state').profiles, normalized.profiles);
  restored.call('undo');
  assert.equal(restored.call('export', { kind: 'build' }), intactBuild);
  assert.deepEqual(restored.call('state').profiles, frozenProfiles);
  h.close();
  restored.close();
});
test('checkpoint navigation saves edited child allocations and restores them after sync or reload', async () => {
  const h = await harness();
  const first = list(h.call('catalog').classes[11].trees)[0].talents[1].id;
  h.call('save', { title: 'Checkpoint navigation' });
  h.call('add', { id: first });
  h.call('checkpoint', { title: 'Second checkpoint' });
  const second = h.call('export', { kind: 'build' });
  h.call('add', { id: first });
  const edited = h.call('export', { kind: 'build' });
  h.call('load', { profileID: 'p1', nodeID: 1 });
  const p = h.call('state').profiles.p1;
  assert.equal(list(p.order).length, 3);
  assert.equal(p.nodes[3].parent, 2);
  assert.equal(p.nodes[3].title, 'Autosaved · Second checkpoint');
  assert.deepEqual(p.nodes[3].build, h.call('decode', { code: edited }).build);
  assert.deepEqual(p.nodes[2].build, h.call('decode', { code: second }).build);
  assert.match(h.call('state').message, /Changes saved/);
  h.call('undo');
  assert.equal(h.call('export', { kind: 'build' }), edited);
  assert.equal(h.call('state').activeNode, 3);
  h.call('redo');
  assert.equal(h.call('state').activeNode, 1);
  h.call('load', { profileID: 'p1', nodeID: 2 });
  h.call('add', { id: first });
  h.call('load', { profileID: 'p1', nodeID: 1 });
  assert.equal(list(h.call('state').profiles.p1.order).length, 3, 'duplicate draft checkpoint');
  const library = h.call('export', { kind: 'library' });
  const synced = await harness();
  synced.call('import', { code: library, includeDrafts: true });
  assert.deepEqual(synced.call('state').profiles, h.call('state').profiles);
  synced.call('load', { profileID: 'p1', nodeID: 3 });
  assert.equal(synced.call('export', { kind: 'build' }), edited);
  const restored = await harness(JSON.parse(JSON.stringify(synced.call('database'))));
  assert.equal(restored.call('export', { kind: 'build' }), edited);
  const saved = restored.call('export', { kind: 'library' });
  assert.equal(restored.raw('load', { profileID: 'p1', nodeID: 999 }).ok, false);
  assert.equal(restored.call('export', { kind: 'library' }), saved);
  restored.call('deleteNode', { profileID: 'p1', nodeID: 2 });
  assert.equal(restored.call('state').profiles.p1.nodes[3], undefined);
  assert.equal(restored.call('export', { kind: 'build' }), edited);
  h.close();
  synced.close();
  restored.close();
});
test('profile links share saved checkpoint branches and exclude unsaved drafts and private data', async () => {
  const source = await harness();
  source.call('import', {
    code: execFileSync('lua5.1', ['tests/fixtures/mage_fire.lua'], { encoding: 'utf8' }).trim(),
  });
  source.call('save', { title: 'Shared Fire' });
  source.call('checkpoint', { title: 'Route A' });
  source.call('remove', { id: 105796 });
  source.call('checkpoint', { title: 'Fire variation' });
  source.call('load', { profileID: 'p1', nodeID: 1 });
  source.call('remove', { id: 105776 });
  source.call('checkpoint', { title: 'Frost variation' });
  const saved = source.call('export', { kind: 'build' });
  source.call('add', { id: 105776 });
  const draft = source.call('export', { kind: 'build' });
  source.call('switch', { classID: 9 });
  source.call('save', { title: 'Private other profile' });
  source.call('characterSave', {
    sheet: { mode: 'manual', name: 'Private stats', stats: { power: 987 } },
  });
  const original = source.call('export', { kind: 'library' });
  const code = source.call('export', { kind: 'profile', profileID: 'p1' });
  const link = source.call('export', { kind: 'profileLink', profileID: 'p1' });
  assert.equal(link, source.call('catalog').buildURL + '#profile=' + code);
  assert.equal(source.call('export', { kind: 'library' }), original);
  assert.equal(source.call('export', { kind: 'profile', profileID: 'p1' }), code);
  const preview = source.call('decode', { code: link, profileOnly: true });
  assert.equal(preview.kind, 'profile');
  assert.equal(preview.nodes, 4);
  assert.equal(preview.selected, 4);
  assert.equal(preview.profile.nodes[3].parent, 2);
  assert.equal(preview.profile.nodes[4].parent, 1);
  assert.equal(preview.profile.nodes[5], undefined);
  assert.notEqual(saved, draft);
  assert.deepEqual(preview.build, source.call('decode', { code: saved }).build);
  assert.equal(JSON.stringify(preview).includes('Private'), false);
  assert.equal(source.call('state').profiles.p1.nodes[5], undefined);
  const dest = await harness();
  assert.equal(dest.raw('export', { kind: 'profileLink' }).ok, false);
  dest.call('switch', { classID: 8 });
  dest.call('save', { title: 'Keep my build' });
  dest.call('auto', { enabled: true });
  dest.call('add', { id: list(list(dest.call('catalog').classes[8].trees)[0].talents)[0].id });
  const previous = dest.call('export', { kind: 'build' });
  dest.call('characterSave', {
    sheet: { mode: 'manual', name: 'Keep stats', stats: { power: 123 } },
  });
  const character = dest.call('database').settings.characters;
  const intact = dest.call('export', { kind: 'library' });
  for (const bad of [
    link + '!',
    link + '%zz',
    code.slice(0, -1),
    source.call('export', { kind: 'link' }),
  ]) {
    assert.equal(dest.raw('import', { code: bad, profileOnly: true }).ok, false);
    assert.equal(dest.call('export', { kind: 'library' }), intact);
  }
  dest.call('import', { code: link, profileOnly: true });
  assert.equal(dest.call('state').activeProfile, 'p2');
  assert.equal(dest.call('state').activeNode, 4);
  assert.equal(dest.call('export', { kind: 'build' }), saved);
  assert.equal(dest.call('state').auto, false);
  assert.deepEqual(dest.call('database').settings.characters, character);
  assert.equal(list(dest.call('state').profiles.p2.order).length, 4);
  assert.equal(dest.call('export', { kind: 'profileLink', profileID: 'p2' }), link);
  assert.deepEqual(dest.call('state').profiles.p2.nodes, preview.profile.nodes);
  dest.call('undo');
  assert.equal(dest.call('export', { kind: 'build' }), previous);
  assert.equal(dest.call('state').auto, true);
  dest.call('redo');
  assert.equal(dest.call('export', { kind: 'build' }), saved);
  dest.call('import', { code: link, profileOnly: true });
  assert.equal(list(dest.call('state').profileOrder).length, 2);
  const restored = await harness(JSON.parse(JSON.stringify(dest.call('database'))));
  assert.equal(restored.call('export', { kind: 'build' }), saved);
  assert.equal(restored.call('state').profiles.p2.nodes[3].parent, 2);
  source.close();
  dest.close();
  restored.close();
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

test('build links preview safely, preserve point order, reject non-build payloads and load undoable drafts', async () => {
  const h = await harness();
  const c = h.call('catalog');
  h.call('save', { title: 'Keep this profile' });
  h.call('checkpoint', { title: 'Keep its branch' });
  h.call('auto', { enabled: true });
  const before = h.call('state').build;
  const profiles = h.call('state').profiles;
  const source = await harness();
  source.call('switch', { classID: 11 });
  source.call('level', { level: 35 });
  const trees = list(c.classes[11].trees);
  for (const tree of trees) source.call('add', { id: list(tree.talents)[0].id, fill: true });
  source.call('save', { title: 'Shared leveling order' });
  const code = source.call('export', { kind: 'build' });
  const link = source.call('export', { kind: 'link' });
  assert.equal(link, c.buildURL + '#build=' + code);
  const library = h.call('export', { kind: 'library' });
  assert.deepEqual(
    h.call('decode', { code: link, buildOnly: true }).build,
    source.call('state').build
  );
  assert.equal(h.call('export', { kind: 'library' }), library);
  for (const invalid of [
    link + '!',
    c.buildURL + '#build=bad',
    source.call('export', { kind: 'character' }),
    source.call('export', { kind: 'library' }),
  ]) {
    assert.equal(h.raw('decode', { code: invalid, buildOnly: true }).ok, false);
    assert.equal(h.raw('import', { code: invalid, buildOnly: true }).ok, false);
    assert.equal(h.call('export', { kind: 'library' }), library);
  }
  h.call('import', { code: link, buildOnly: true });
  assert.equal(h.call('export', { kind: 'build' }), code);
  assert.equal(h.call('state').auto, false);
  assert.deepEqual(h.call('state').profiles, profiles);
  h.call('undo');
  assert.deepEqual(h.call('state').build, before);
  assert.equal(h.call('state').auto, true);
  h.call('redo');
  assert.equal(h.call('export', { kind: 'build' }), code);
  const restored = await harness(h.call('database'));
  assert.equal(restored.call('export', { kind: 'link' }), link);
  restored.call('preview', { count: 3 });
  const preview = restored.call('decode', { code: restored.call('export', { kind: 'link' }) });
  assert.equal(preview.build.level, 12);
  assert.equal(list(preview.build.order).length, 3);
  source.close();
  restored.close();
  h.close();
});
test('checkpoint levels override conflicting Auto and successful saves discard stale Redo', async () => {
  const h = await harness();
  h.call('switch', { classID: 8 });
  h.call('level', { level: 60 });
  const id = list(list(h.call('catalog').classes[8].trees)[1].talents)[2].id;
  for (let i = 0; i < 5; i++) h.call('add', { id });
  const profile = h.call('save', { title: 'Level 60, five points' });
  const code = h.call('export', { kind: 'build' });
  h.call('auto', { enabled: true });
  assert.equal(h.call('state').build.level, 14);
  h.call('load', { profileID: profile.id, nodeID: 1 });
  assert.equal(h.call('export', { kind: 'build' }), code);
  assert.equal(h.call('state').auto, false);
  assert.equal(h.call('state').dirty, false);
  assert.match(h.call('state').message, /Auto turned off to restore saved level 60/);
  const skill = list(h.call('skills', { query: 'Fireball' })).find(
    (e) => e.skill.name === 'Fireball'
  );
  assert.match(skill.progression.summary, /Max rank 12 Lv. 60/);
  h.call('undo');
  assert.equal(h.call('state').build.level, 14);
  assert.equal(h.call('state').auto, true);
  h.call('redo');
  assert.equal(h.call('state').build.level, 60);
  assert.equal(h.call('state').auto, false);
  const empty = await harness();
  const first = list(list(empty.call('catalog').classes[11].trees)[0].talents)[0].id;
  empty.call('add', { id: first });
  empty.call('undo');
  assert.equal(empty.call('state').redo, 1);
  assert.equal(empty.raw('save', { title: '' }).ok, false);
  assert.equal(empty.call('state').redo, 1);
  const saved = empty.call('save', { title: 'New saved profile' });
  assert.equal(empty.call('state').redo, 0);
  assert.equal(empty.raw('redo').ok, false);
  assert.equal(empty.call('state').activeProfile, saved.id);
  assert.equal(empty.call('state').build.name, 'New saved profile');
  assert.equal(list(empty.call('state').build.order).length, 0);
  empty.call('add', { id: first });
  empty.call('undo');
  const node = empty.call('checkpoint', { title: 'Empty branch' });
  assert.equal(empty.call('state').redo, 0);
  assert.equal(empty.call('state').activeNode, node.id);
  const restored = await harness(empty.call('database'));
  assert.equal(restored.call('state').redo, 0);
  assert.equal(restored.call('state').activeProfile, saved.id);
  restored.close();
  empty.close();
  h.close();
});
test('skill summary separates first unlock and displayed rank level without a duplicate maximum line', async () => {
  const h = await harness();
  const entry = (name) =>
    list(h.call('skills', { query: name })).find((e) => e.skill.name === name);
  h.call('level', { level: 60 });
  assert.equal(entry('Shred').progression.summary, 'Lv. 22 · Max rank 5 Lv. 54');
  assert.equal(entry('Shred').progression.secondary, undefined);
  h.call('level', { level: 45 });
  assert.equal(entry('Shred').progression.summary, 'Lv. 22 · Rank 3 Lv. 38');
  assert.equal(entry('Shred').progression.secondary, 'Rank 4 Lv. 46');
  h.call('simpleView', { enabled: true });
  assert.equal(entry('Shred').progression.summary, 'Lv. 22 · Rank 3 Lv. 38');
  h.close();
});

test('Feral tier restrictions explain supporting points and allow moving them between earlier rows', async () => {
  const h = await harness();
  try {
    h.call('switch', { classID: 11 });
    h.call('auto', { enabled: false });
    h.call('level', { level: 60 });
    for (const [id, count] of [
      [104938, 5],
      [104939, 3],
      [104941, 2],
      [104945, 3],
      [104948, 2],
      [104944, 1],
    ])
      for (let n = 0; n < count; n++) h.call('add', { id });
    const original = h.call('export', { kind: 'build' });
    const blocked = h.raw('remove', { id: 104939 });
    assert.equal(blocked.ok, false);
    assert.match(blocked.error, /Shredding Attacks.*9\/10 supporting points/);
    assert.equal(h.call('export', { kind: 'build' }), original);
    h.call('save', { title: 'Feral fixture' });
    h.call('add', { id: 104940 });
    h.call('remove', { id: 104939 });
    assert.equal(h.call('state').counts[104939], 2);
    h.call('undo');
    assert.equal(h.call('state').counts[104939], 3);
    h.call('redo');
    assert.equal(h.call('state').counts[104939], 2);
  } finally {
    h.close();
  }
});

test('updating a checkpoint preserves its graph and saved-only links across reload and sync', async () => {
  const h = await harness();
  assert.equal(h.raw('updateCheckpoint').ok, false);
  h.call('switch', { classID: 8 });
  h.call('level', { level: 60 });
  h.call('save', { title: 'Editable routes' });
  h.call('add', { id: list(list(h.call('catalog').classes[8].trees)[1].talents)[2].id });
  h.call('checkpoint', { title: 'Route A' });
  h.call('add', { id: list(list(h.call('catalog').classes[8].trees)[1].talents)[2].id });
  h.call('checkpoint', { title: 'Child of A' });
  h.call('load', { profileID: 'p1', nodeID: 1 });
  h.call('checkpoint', { title: 'Sibling' });
  h.call('load', { profileID: 'p1', nodeID: 2 });
  const before = JSON.parse(JSON.stringify(h.call('state').profiles.p1));
  const original = h.call('export', { kind: 'profileLink' });
  h.call('add', { id: list(list(h.call('catalog').classes[8].trees)[1].talents)[2].id });
  h.call('level', { level: 50 });
  assert.equal(h.call('export', { kind: 'profileLink' }), original);
  const draft = h.call('export', { kind: 'build' });
  h.call('preview', { count: 0 });
  assert.equal(h.raw('updateCheckpoint').ok, false);
  h.call('preview');
  h.call('updateCheckpoint');
  const after = h.call('state');
  assert.equal(after.dirty, false);
  assert.equal(after.activeNode, 2);
  const expected = JSON.parse(JSON.stringify(before));
  expected.nodes[2].build = after.build;
  assert.deepEqual(after.profiles.p1, expected);
  const link = h.call('export', { kind: 'profileLink' });
  assert.notEqual(link, original);
  const decoded = h.call('decode', { code: link, profileOnly: true });
  assert.equal(decoded.nodes, 4);
  assert.equal(decoded.selected, 2);
  assert.deepEqual(decoded.build, after.build);
  h.call('load', { profileID: 'p1', nodeID: 1 });
  h.call('load', { profileID: 'p1', nodeID: 2 });
  assert.equal(list(h.call('state').profiles.p1.order).length, 4);
  assert.equal(h.call('export', { kind: 'build' }), draft);
  h.call('add', { id: list(list(h.call('catalog').classes[8].trees)[1].talents)[2].id });
  h.call('updateCheckpoint');
  h.call('undo');
  assert.equal(h.call('state').dirty, true);
  h.call('updateCheckpoint');
  assert.equal(h.call('state').redo, 0);
  assert.equal(h.raw('redo').ok, false);
  const restored = await harness(h.call('database'));
  assert.equal(restored.call('state').dirty, false);
  assert.deepEqual(restored.call('state').profiles, h.call('state').profiles);
  const imported = await harness();
  imported.call('import', { code: link, profileOnly: true });
  assert.deepEqual(imported.call('state').profiles.p1, expected);
  const blocked = await harness({ ...h.call('database'), schema: 999 });
  assert.equal(blocked.raw('updateCheckpoint').ok, false);
  const intact = h.call('export', { kind: 'library' });
  assert.equal(h.raw('import', { code: link + '!', profileOnly: true }).ok, false);
  assert.equal(h.call('export', { kind: 'library' }), intact);
  h.call('deleteNode', { profileID: 'p1', nodeID: 2 });
  assert.equal(h.call('state').profiles.p1.nodes[3], undefined);
  assert.ok(h.call('state').profiles.p1.nodes[4]);
  for (const engine of [h, restored, imported, blocked]) engine.close();
});
