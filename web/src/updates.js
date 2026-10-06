// Observe a complete release download before offering to replace the cached app.
export function createUpdateMonitor(registration, notify) {
  const observed = new WeakSet();
  let manual = false;
  let checking;
  let failed = false;
  function report(kind) {
    notify({ kind, manual });
    if (['ready', 'current', 'failed'].includes(kind)) manual = false;
  }
  function inspect() {
    if (registration.waiting) {
      report('ready');
      return 'ready';
    }
    const worker = registration.installing;
    if (worker && worker.state !== 'redundant') {
      observe(worker);
      report('downloading');
      return 'downloading';
    }
    return null;
  }
  function observe(worker) {
    if (observed.has(worker)) return;
    observed.add(worker);
    worker.addEventListener('statechange', () => {
      if (worker.state === 'installed') setTimeout(inspect, 0);
      else if (worker.state === 'redundant') {
        failed = true;
        report('failed');
      } else if (worker.state === 'activated' && !registration.waiting) report('current');
    });
  }
  registration.addEventListener('updatefound', inspect);
  inspect();
  return {
    check(quiet = false) {
      manual = manual || !quiet;
      if (checking) return checking;
      if (registration.waiting) {
        report('ready');
        return Promise.resolve('ready');
      }
      report('checking');
      failed = false;
      checking = (async () => {
        try {
          await registration.update();
          if (failed) return 'failed';
          const result = inspect();
          if (result) return result;
          report('current');
          return 'current';
        } catch {
          report('failed');
          return 'failed';
        }
      })().finally(() => {
        checking = null;
      });
      return checking;
    },
  };
}
