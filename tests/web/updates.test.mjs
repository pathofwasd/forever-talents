import test from 'node:test';
import assert from 'node:assert/strict';
import { createUpdateMonitor } from '../../web/src/updates.js';
const turn = () => new Promise((resolve) => setTimeout(resolve, 0));
class Worker extends EventTarget {
  state = 'installing';
  change(state) {
    this.state = state;
    this.dispatchEvent(new Event('statechange'));
  }
}
function setup(update = async () => {}) {
  const registration = new EventTarget();
  Object.assign(registration, { update, active: {}, installing: null, waiting: null });
  const states = [];
  const monitor = createUpdateMonitor(registration, (state) => states.push(state));
  return { registration, states, monitor };
}
test('manual checks distinguish current, offline failure and a complete waiting release', async () => {
  const t = setup();
  assert.equal(await t.monitor.check(), 'current');
  assert.deepEqual(t.states.at(-1), { kind: 'current', manual: true });
  t.registration.update = async () => {
    throw Error('offline');
  };
  assert.equal(await t.monitor.check(), 'failed');
  assert.deepEqual(t.states.at(-1), { kind: 'failed', manual: true });
  t.registration.update = () => {
    throw Error('registration unavailable');
  };
  assert.equal(await t.monitor.check(), 'failed');
  t.registration.update = async () => {};
  assert.equal(await t.monitor.check(), 'current', 'a synchronous failure prevented later checks');
  t.registration.waiting = new Worker();
  assert.equal(await t.monitor.check(), 'ready');
  assert.deepEqual(t.states.at(-1), { kind: 'ready', manual: true });
});
test('a slow download never reports current and offers an update only after installation completes', async () => {
  const t = setup();
  t.registration.update = async () => {
    t.registration.installing = new Worker();
    t.registration.dispatchEvent(new Event('updatefound'));
  };
  assert.equal(await t.monitor.check(), 'downloading');
  assert.equal(
    t.states.some((s) => s.kind === 'ready' || s.kind === 'current'),
    false
  );
  const worker = t.registration.installing;
  worker.change('installed');
  t.registration.installing = null;
  t.registration.waiting = worker;
  await turn();
  assert.deepEqual(t.states.at(-1), { kind: 'ready', manual: true });
  assert.equal(await t.monitor.check(true), 'ready');
  assert.equal(t.states.at(-1).manual, false);
});
test('failed cache installation and concurrent checks cannot falsely report an up-to-date app', async () => {
  let finish;
  const t = setup();
  t.registration.update = () =>
    new Promise((resolve) => {
      finish = resolve;
    });
  const first = t.monitor.check(true);
  const second = t.monitor.check();
  assert.equal(first, second);
  const worker = new Worker();
  t.registration.installing = worker;
  t.registration.dispatchEvent(new Event('updatefound'));
  worker.change('redundant');
  t.registration.installing = null;
  finish();
  assert.equal(await second, 'failed');
  assert.deepEqual(t.states.at(-1), { kind: 'failed', manual: true });
  assert.equal(
    t.states.some((s) => s.kind === 'current'),
    false
  );
});
