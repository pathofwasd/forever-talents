import './style.css';
import { createEngine, list } from './engine.js';
import { createSimulatorUI } from './simulator.js';
const $ = (s, root = document) => root.querySelector(s);
const esc = (v) =>
  String(v ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]
  );
const img = (icon, cls = 'icon') =>
  `<img class="${cls}" src="${new URL(`generated/icons/${encodeURIComponent(icon)}.jpg`, document.baseURI)}" alt="" loading="lazy" decoding="async">`;
const btn = (label, action, data = '', cls = '', disabled = false) =>
  `<button type="button" class="${cls}" data-action="${action}" ${data} ${disabled ? 'disabled' : ''}>${label}</button>`;
const KEY = 'forever-talents.pwa.library.v1';
let engine,
  catalog,
  state,
  status = 'Preparing offline files…',
  selected = new Map(),
  hovered = null;
let storageBlocked = false,
  unreadableSave = '';
let panel = 'trees',
  treeTab = 0,
  talentQuery = '',
  skillQuery = '',
  skillFilter = 'all',
  toastTimer,
  installPrompt,
  registration;
const modal = $('#modal'),
  app = $('#app');
function toast(message, error = false) {
  const node = $('#toast');
  node.textContent = message;
  node.className = error ? 'show error' : 'show';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (node.className = ''), 6000);
}
function persist() {
  if (state.readOnly || storageBlocked) return;
  try {
    localStorage.setItem(KEY, JSON.stringify(engine.call('database')));
  } catch (e) {
    toast('Browser storage is full or unavailable. Export your library now to keep changes.', true);
  }
}
function update() {
  const previous = state;
  state = engine.call('state');
  if (previous.view.classID !== state.view.classID) changeContext();
  else if (previous.view.raceID !== state.view.raceID) {
    for (const [key, skill] of selected) if (skill.kind === 'racial') selected.delete(key);
    if (hovered?.kind === 'racial') hovered = null;
  }
  persist();
  render();
}
function act(name, payload = {}) {
  try {
    const value = engine.call(name, payload);
    update();
    return value;
  } catch (e) {
    toast(e.message, true);
    return null;
  }
}
function cls() {
  return catalog.classes[state.view.classID];
}
function talents() {
  return list(cls().trees).flatMap((t) => list(t.talents));
}
function talent(id) {
  return talents().find((t) => t.id === Number(id));
}
function order() {
  return list(state.view.order);
}
function highlight() {
  const ids = new Set();
  for (const skill of [...selected.values(), ...(hovered ? [hovered] : [])])
    for (const relation of list(skill.related)) ids.add(relation.id);
  return ids;
}
function skillKey(s) {
  return `${s.kind}:${s.name}`;
}
function render() {
  const focus = document.activeElement;
  const key = focus?.id;
  const start = focus?.selectionStart,
    end = focus?.selectionEnd;
  const c = cls(),
    race = catalog.races[state.view.raceID],
    allTrees = list(c.trees),
    points = order().length;
  app.innerHTML = `<header class="topbar"><a class="brand" href="./" aria-label="Forever Talents home"><img src="./icon.svg" alt="" width="36" height="36"><span>Forever <strong>Talents</strong><small><span class="desktop-brand">PLAN YOUR JOURNEY</span><span class="mobile-brand">${esc(status)}</span></small></span></a><div class="top-actions"><span class="connection" id="offline-status">${esc(status)}</span>${btn('Install', 'install', '', 'quiet')}${btn('<svg class="character-button-icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="7" r="4"/><path d="M4 22v-3a8 8 0 0 1 16 0v3"/></svg><span class="character-button-label">Character</span>', 'character-sheet', 'aria-label="Character" title="Character stats and equipment"', 'quiet character-button')}${btn('Guide', 'help', '', 'quiet')}${btn('Import', 'import')}${btn('Share', 'share', '', 'primary')}</div></header>
  <div id="update-banner" class="update-banner" hidden>A new version is ready. Your saved builds will be kept. ${btn('Update now', 'update', '', 'primary')}</div>
  <main><section class="controls" aria-label="Character and build controls"><div class="class-choices" aria-label="Class">${list(
    catalog.classOrder
  )
    .map((id) =>
      btn(
        `${img(catalog.classes[id].icon)}<span class="class-label">${esc(catalog.classes[id].name)}</span>`,
        'class',
        `data-id="${id}" aria-label="${esc(catalog.classes[id].name)}" title="${esc(catalog.classes[id].name)}" aria-pressed="${Number(id) === state.view.classID}"`,
        Number(id) === state.view.classID ? 'class-choice active' : 'class-choice'
      )
    )
    .join('')}</div><label class="race-select">Race<select id="race">${list(c.races)
    .map(
      (id) =>
        `<option value="${id}" ${Number(id) === state.view.raceID ? 'selected' : ''}>${esc(catalog.races[id].name)}</option>`
    )
    .join(
      ''
    )}</select></label>${btn('Race atlas', 'races', '', 'quiet')}<div class="level-controls"><label for="level">${state.auto ? 'Level' : 'Target'}</label>${btn('−', 'level-down', '', 'square', state.auto || state.preview !== undefined)}<input id="level" type="number" min="1" max="60" value="${state.viewLevel}" aria-label="Character target level" ${state.auto || state.preview !== undefined ? 'disabled' : ''}>${btn('+', 'level-up', '', 'square', state.auto || state.preview !== undefined)}${btn('Auto', 'auto', `aria-pressed="${state.auto}"`, state.auto ? 'active' : '')}</div><div class="edit-controls">${btn('↶ Undo', 'undo', '', '', !state.undo)}${btn('↷ Redo', 'redo', '', '', !state.redo)}${btn('Reset', 'reset')}</div></section>
  <section class="hero"><div>${img(c.icon, 'hero-icon')}<div><p class="eyebrow">${esc(race.name)} · ${esc(race.faction)}</p><h1>${esc(c.name)} <span>${esc(state.build.name)}</span></h1><p class="spec-counts">${allTrees.map((t) => `<span class="spec-item">${esc(t.name)} <b>${state.treeCounts[t.id] || 0}</b></span>`).join('<span class="spec-divider">/</span>')}</p></div></div><div class="hero-level"><strong>Level ${state.viewLevel}</strong><span>${points} / ${state.budget} points · ${Math.max(0, state.budget - points)} left</span><small>${state.preview !== undefined ? 'Leveling preview · editing paused' : state.auto ? 'Auto follows spent talents' : `Spent talents require level ${state.requiredLevel}`}</small></div></section>
  ${state.preview !== undefined ? `<aside class="preview-banner">Previewing point ${state.preview} of ${list(state.build.order).length}. ${btn('Full build', 'full')}${btn('Branch here', 'branch', '', 'primary')}</aside>` : ''}
  <div class="workspace" data-panel="${panel}"><aside class="panel skills-panel" aria-label="Skills and ranks"><div class="section-heading"><h2>Skills & ranks</h2><span>${state.viewLevel} LV</span></div><p class="muted">Check to keep talent highlights.</p><input id="skill-search" type="search" placeholder="Search skills or effects…" value="${esc(skillQuery)}" aria-label="Search skills"><select id="skill-filter" aria-label="Skill category">${[
    ['all', 'All skills & racials'],
    ['now', 'Available at this level'],
    ['talent', 'Unlocked by talents'],
    ['racial', 'Racial traits'],
  ]
    .map(
      ([key, label]) =>
        `<option value="${key}" ${skillFilter === key ? 'selected' : ''}>${label}</option>`
    )
    .join(
      ''
    )}</select><div class="skill-list" id="skill-list"></div>${btn('Clear highlights', 'clear-highlights', '', 'wide')}</aside>
  <section class="talents-panel" aria-label="Talent trees"><div class="talent-heading"><h2>Talent trees</h2><input id="talent-search" type="search" placeholder="Search talents or effects…" value="${esc(talentQuery)}" aria-label="Search talents"></div><nav class="tree-tabs" aria-label="Talent tree">${allTrees.map((t, i) => btn(`${esc(t.name)} <b>${state.treeCounts[t.id] || 0}</b>`, 'tree-tab', `data-index="${i}" aria-pressed="${i === treeTab}"`, i === treeTab ? 'active' : '')).join('')}</nav><div class="trees">${allTrees.map((tree, i) => renderTree(tree, i)).join('')}</div><p class="tree-hint"><span class="desktop-hint">Click +1 · right-click −1 · Shift fills / clears · Ctrl inspects</span><span class="touch-hint">Tap a talent to read it, then choose Add or Remove.</span></p><div class="racials"><h2>Racial traits</h2><div id="racial-list"></div></div></section>
  <aside class="panel builds-panel" aria-label="Build library and talent order"><div class="section-heading"><h2>Your journey</h2><span class="saved-dot">${state.readOnly || storageBlocked ? 'Saving paused' : 'Autosaved'}</span></div><div class="build-actions">${btn('Save build', 'save', '', 'primary')}${btn('Checkpoint', 'checkpoint', '', '', !state.activeProfile)}</div><div id="history-graph"></div><div class="section-heading order-heading"><h3>Talent order</h3><span>${list(state.build.order).length} ${list(state.build.order).length === 1 ? 'step' : 'steps'}</span></div><div class="order-list">${renderOrder()}</div>${btn('Library & sync', 'library', '', 'wide')}</aside>
  <section class="panel more-panel"><h2>Atlas & tools</h2>${storageBlocked || state.readOnly ? `<p class="callout">Saving is paused to preserve unreadable or newer browser data. Export this session’s work as sharing strings. ${btn('Download original saved data', 'recovery')}</p>` : ''}<p class="muted">Your whole library lives on this device. Use Library & sync to move it between devices and the addon.</p><div class="tool-grid">${btn('Library & sync', 'library')}${btn('Character & simulator', 'character-sheet')}${btn('Race & class atlas', 'races')}${btn('Hunter pet atlas', 'pets')}${btn('Forever perks', 'perks')}${btn('How to use', 'help')}${btn('Install app', 'install')}</div><p class="muted">Forever ${esc(catalog.meta.build)} · data ${esc(catalog.meta.tag)} · v${esc(catalog.version)}</p><p><a href="./NOTICE.txt" target="_blank" rel="noopener">Data & artwork credits</a> · <a href="./LICENSE.txt" target="_blank" rel="noopener">License</a> · <a href="./THIRD-PARTY.txt" target="_blank" rel="noopener">Runtime credits</a></p></section></div>
  <footer><span>Forever ${esc(catalog.meta.build)} · v${esc(catalog.version)} · data ${esc(catalog.meta.tag)}</span><div>${btn('Pet atlas', 'pets', '', 'quiet')}${btn('Perks', 'perks', '', 'quiet')}${btn('Library & sync', 'library', '', 'quiet')}</div><p class="project-notice"><span>Free, unofficial community project. Not affiliated with or endorsed by Blizzard Entertainment.</span><span>World of Warcraft artwork and text © Blizzard Entertainment and respective rights holders.</span><a href="./NOTICE.txt" target="_blank" rel="noopener">Copyright & ownership notice <span class="notice-link-hint">(opens in a new tab)</span></a></p></footer></main>
  <nav class="mobile-nav" aria-label="Calculator sections">${[
    ['trees', '◇', 'Trees'],
    ['skills', '☷', 'Skills'],
    ['builds', '⑂', 'Builds'],
    ['more', '⋯', 'More'],
  ]
    .map(([id, icon, label]) =>
      btn(
        `<span>${icon}</span>${label}`,
        'panel',
        `data-panel="${id}" aria-current="${panel === id ? 'page' : 'false'}"`,
        panel === id ? 'active' : ''
      )
    )
    .join('')}</nav>`;
  renderSkills();
  renderHistory();
  paintHighlights();
  if (registration?.waiting) $('#update-banner').hidden = false;
  if (key) {
    const node = document.getElementById(key);
    if (node) {
      node.focus({ preventScroll: true });
      if (start !== null && start !== undefined)
        try {
          node.setSelectionRange(start, end);
        } catch {}
    }
  }
}
function renderTree(tree, i) {
  const nodes = list(tree.talents),
    access = engine.call('talents', { query: talentQuery });
  const byID = Object.fromEntries(nodes.map((t) => [t.id, t]));
  const arrows = nodes
    .flatMap((t) =>
      list(t.requires).map((req) => {
        const p = byID[req.id];
        if (!p) return '';
        const x1 = 12.5 + p.col * 25,
          y1 = 7 + p.row * 13.7,
          x2 = 12.5 + t.col * 25,
          y2 = 7 + t.row * 13.7;
        const active = (state.counts[req.id] || 0) >= req.points;
        return `<path d="M${x1} ${y1 + 4.8} V${y2 - 7} H${x2} V${y2 - 5.2}" class="${active ? 'met' : ''}" marker-end="url(#arrow-${tree.id})"/>`;
      })
    )
    .join('');
  return `<article class="tree theme-${i}" data-tree-index="${i}" ${i === treeTab ? 'data-selected="true"' : ''}><div class="tree-title">${img(tree.icon)}<h3>${esc(tree.name)}</h3><b>${state.treeCounts[tree.id] || 0}</b></div><div class="tree-grid"><svg viewBox="0 0 100 100" preserveAspectRatio="none" class="connectors" aria-hidden="true"><defs><marker id="arrow-${tree.id}" markerWidth="4" markerHeight="4" refX="2" refY="2" orient="auto"><path d="M0 0 L4 2 L0 4"/></marker></defs>${arrows}</svg>${nodes
    .map((t) => {
      const rank = state.counts[t.id] || 0,
        a = access[t.id];
      return `<button type="button" class="talent ${rank === t.max ? 'maxed' : rank ? 'spent' : a.available ? 'available' : 'locked'} ${a.match ? '' : 'unmatched'}" style="--col:${t.col};--row:${t.row}" data-talent="${t.id}" aria-label="${esc(t.name)}: ${rank} of ${t.max} ranks${a.available ? ', can add a point' : ''}" data-available="${a.available}" ${state.preview !== undefined ? 'data-preview="true"' : ''}>${img(t.icon)}<span class="rank">${rank}<span>/${t.max}</span></span></button>`;
    })
    .join(
      ''
    )}</div><div class="tree-bottom">${btn('Reset tree', 'reset-tree', `data-id="${tree.id}"`, 'wide')}</div></article>`;
}
function renderSkills() {
  const entries = list(engine.call('skills', { query: skillQuery, filter: skillFilter }));
  $('#skill-list').innerHTML = entries.length
    ? entries
        .map(
          ({ skill: s, current }) =>
            `<div class="skill-row"><input type="checkbox" data-skill-check="${esc(s.name)}" aria-label="Keep ${esc(s.name)} talent highlights" ${selected.has(skillKey(s)) ? 'checked' : ''}><button class="skill-details" data-skill="${esc(s.name)}">${img(s.icon)}<span><strong>${esc(s.name)}</strong><small>${s.unlock ? `${esc(s.unlock.treeName)} talent · ` : `Lv. ${s.firstLevel} · `}${current ? esc(current.label || 'available') : 'not yet available'}</small></span></button></div>`
        )
        .join('')
    : '<p class="empty">No matches. Try another effect or category.</p>';
  const racials = list(engine.call('skills', { filter: 'racial' }));
  $('#racial-list').innerHTML = racials
    .map(
      ({ skill: s }) =>
        `<label class="racial"><input type="checkbox" data-skill-check="${esc(s.name)}" ${selected.has(skillKey(s)) ? 'checked' : ''} aria-label="Keep ${esc(s.name)} highlights">${btn(`${img(s.icon)}${esc(s.name)}`, 'racial', `data-name="${esc(s.name)}"`, 'quiet')}</label>`
    )
    .join('');
}
function paintHighlights() {
  const ids = highlight();
  for (const node of document.querySelectorAll('[data-talent]'))
    node.classList.toggle('highlighted', ids.has(Number(node.dataset.talent)));
}
function renderOrder() {
  const index = Object.fromEntries(talents().map((t) => [t.id, t]));
  return (
    list(state.build.order)
      .map(
        (id, i) =>
          `<div class="order-step ${state.preview === i + 1 ? 'active' : ''}">${btn(`<span class="step-level">${i + 10}</span>${img(index[id].icon)}<span>${esc(index[id].name)}</span>`, 'preview', `data-count="${i + 1}"`, 'step-main')}${btn('↑', 'reorder', `data-from="${i + 1}" data-to="${i}" aria-label="Move point ${i + 1} earlier"`, 'step-move', i === 0 || state.preview !== undefined)}${btn('↓', 'reorder', `data-from="${i + 1}" data-to="${i + 2}" aria-label="Move point ${i + 1} later"`, 'step-move', i === list(state.build.order).length - 1 || state.preview !== undefined)}</div>`
      )
      .join('') ||
    '<p class="empty">Your first point starts at level 10. Each point is saved in order.</p>'
  );
}
function renderHistory() {
  const p = state.profiles[state.activeProfile];
  if (!p) {
    $('#history-graph').innerHTML =
      '<p class="empty">Save a build to start your checkpoint tree. Load any checkpoint to grow a new branch.</p>';
    return;
  }
  const depth = {},
    nodes = list(p.order).map((id, i) => {
      const n = p.nodes[id];
      depth[id] = n.parent ? depth[n.parent] + 1 : 0;
      return { ...n, x: depth[id] * 28, y: i * 64 };
    });
  const links = nodes
    .filter((n) => n.parent)
    .map((n) => {
      const parent = nodes.find((p) => p.id === n.parent);
      return `<path d="M${parent.x + 10} ${parent.y + 25} V${n.y + 25} H${n.x + 10}"/>`;
    })
    .join('');
  $('#history-graph').innerHTML =
    `<div class="graph-heading"><h3>${esc(p.name)}</h3><small>${state.dirty ? 'Draft changes' : 'At checkpoint'}</small></div><div class="graph-scroll"><div class="graph" style="height:${nodes.length * 64}px;min-width:${Math.max(...nodes.map((n) => n.x)) + 204}px"><svg aria-hidden="true" width="100%" height="100%">${links}</svg>${nodes.map((n) => `<div class="graph-node ${state.activeNode === n.id ? 'active' : ''}" style="left:${n.x}px;top:${n.y}px">${btn(`<strong>${esc(n.title)}</strong><small>Lv. ${n.build.level} · ${list(n.build.order).length} ${list(n.build.order).length === 1 ? 'point' : 'points'}</small>`, 'load', `data-profile="${p.id}" data-node="${n.id}" title="${esc(n.title)}"`, 'node-main')}${btn('×', 'delete-node', `data-profile="${p.id}" data-node="${n.id}" aria-label="Delete ${esc(n.title)} and descendants"`, 'node-delete')}</div>`).join('')}</div></div>`;
}
function openDialog(title, html, wide = false) {
  if (!modal.open) {
    const active = document.activeElement;
    modal.returnSelector = active?.id
      ? '#' + CSS.escape(active.id)
      : active?.dataset.talent
        ? `[data-talent="${active.dataset.talent}"]`
        : active?.dataset.skill
          ? `[data-skill="${CSS.escape(active.dataset.skill)}"]`
          : active?.dataset.action
            ? `[data-action="${active.dataset.action}"]`
            : null;
  }
  $('#tooltip').hidden = true;
  modal.innerHTML = `<div class="modal-head"><h2 id="dialog-title">${esc(title)}</h2>${btn('×', 'close', `aria-label="Close dialog"`, 'close')}</div><div class="modal-body">${html}</div>`;
  modal.className = wide ? 'wide-modal' : '';
  modal.setAttribute('aria-labelledby', 'dialog-title');
  if (!modal.open) modal.showModal();
  modal.scrollTop = 0;
  modal.querySelector('[data-action="close"]').focus({ preventScroll: true });
}
function closeDialog() {
  modal.close();
  hovered = null;
  paintHighlights();
}
function description(t) {
  const rank = state.counts[t.id] || 0,
    ranks = list(t.ranks);
  return `<p class="eyebrow">${esc(t.treeName || list(cls().trees).find((tree) => list(tree.talents).some((n) => n.id === t.id))?.name)} · row ${t.row + 1}</p><div class="detail-title">${img(t.icon)}<h3>${esc(t.name)}</h3><b>${rank}/${t.max}</b></div>${rank ? `<p class="description"><span class="muted">Current rank ${rank}</span><br>${esc(ranks[rank - 1].text)}</p>` : ''}${rank < t.max ? `<p class="description"><span class="gold">Next rank ${rank + 1}</span><br>${esc(ranks[rank].text)}</p>` : ''}<p class="muted">${esc(engine.call('talents')[t.id].reason || 'Available to learn.')} ${list(
    t.requires
  )
    .map((r) => `Requires ${r.points} ${esc(r.name)}.`)
    .join(' ')}</p>`;
}
function showTalent(id) {
  const t = talent(id);
  if (!t) return;
  const related = list(engine.call('talentSkills', { id: t.id }));
  openDialog(
    t.name,
    `${description(t)}<div class="allocation-actions">${btn('− Remove', 'talent-remove', `data-id="${id}"`, '', !(state.counts[id] > 0) || state.preview !== undefined)}${btn('+ Add point', 'talent-add', `data-id="${id}"`, 'primary', state.preview !== undefined)}${btn('Fill ranks', 'talent-fill', `data-id="${id}"`, '', state.preview !== undefined)}${btn('Clear ranks', 'talent-clear', `data-id="${id}"`, '', state.preview !== undefined)}</div><details><summary>Every rank</summary>${list(
      t.ranks
    )
      .map((r, i) => `<p><b>Rank ${i + 1}</b><br>${esc(r.text)}</p>`)
      .join(
        ''
      )}</details>${related.length ? `<h3>Related skills</h3><div class="chips">${related.map((n) => btn(esc(n), 'related-skill', `data-name="${esc(n)}"`)).join('')}</div>` : ''}`
  );
}
function showSkill(name) {
  try {
    const s = engine.call('skill', { name });
    hovered = s;
    paintHighlights();
    const ranks = list(s.ranks);
    const rel = list(s.related);
    openDialog(
      s.name,
      `<div class="detail-title">${img(s.icon)}<h3>${esc(s.name)}</h3><span class="badge">${esc(s.kind)}</span></div>${s.unlock ? `<p class="callout">Unlocked by <b>${esc(s.unlock.name)}</b> in ${esc(s.unlock.treeName)}, row ${s.unlock.row + 1} (${s.unlock.gate} points in tree first).</p>` : `<p class="muted">First learned at level ${s.firstLevel}. All captured ranks appear below.</p>`}<label class="pin"><input type="checkbox" data-skill-check="${esc(s.name)}" ${selected.has(skillKey(s)) ? 'checked' : ''}>Keep talent highlights</label><div class="skill-ranks">${ranks.map((r, i) => `<article class="rank-card ${r.live ? '' : 'archived'}"><div><b>${esc(r.label || 'Ability')}</b><span>Lv. ${r.level}${r.talentRank ? ` · talent rank ${r.talentRank}` : ''}${r.fromLevel ? ` · Lv. ${r.fromLevel}–${r.toLevel || 60}` : ''}${r.live ? '' : ' · archived'}</span></div><p>${esc(r.text || 'No description recorded in the captured snapshot.')}</p>${btn('Open simulator', 'simulate', `data-name="${esc(s.name)}" data-rank="${i + 1}"`, 'quiet')}</article>`).join('')}</div><h3>Talent interactions <span class="muted">${rel.length}</span></h3>${rel.length ? rel.map((r) => `<div class="relation">${btn(esc(talent(r.id)?.name || r.id), 'locate', `data-id="${r.id}"`)}<p>${esc(r.reason)}</p></div>`).join('') : '<p class="muted">No specific talent interaction is described in the captured data.</p>'}`
    );
  } catch (e) {
    toast(e.message, true);
  }
}
function showImport(code = '') {
  openDialog(
    'Import from addon or another device',
    `<p class="muted">Build <b>FT1</b> · character <b>FC1</b> · stats & gear <b>FS2</b> (FS1 supported) · full library <b>FL1</b>. Your draft stays here until you load.</p><label class="field-label" for="import-code">Paste a complete sharing string</label><textarea id="import-code" rows="5" maxlength="3145728" spellcheck="false" autocapitalize="off" autocomplete="off">${esc(code)}</textarea><div id="import-preview" class="callout">Paste a string to preview it.</div><label class="pin" id="import-drafts-label" hidden><input id="import-drafts" type="checkbox">Also replace class drafts when merging the library</label><p class="muted" id="import-note"></p><div class="dialog-actions">${btn('Load snapshot', 'import-load', '', 'primary', true)}${btn('Cancel', 'close')}</div>`
  );
  if (code) previewImport();
  $('#import-code').focus();
}
function previewImport() {
  const input = $('#import-code').value;
  const load = $('[data-action="import-load"]');
  try {
    const snap = engine.call('decode', { code: input });
    load.disabled = false;
    $('#import-drafts-label').hidden = snap.kind !== 'library';
    load.textContent = snap.kind === 'library' ? 'Merge library' : 'Load snapshot';
    $('#import-preview').textContent =
      snap.kind === 'library'
        ? `${snap.profiles} profiles · ${snap.nodes} checkpoints · ${snap.drafts} class drafts`
        : `${catalog.classes[(snap.build || snap.stats).classID].name} · ${catalog.races[(snap.build || snap.stats).raceID].name} · level ${(snap.build || snap.stats).level} · ${snap.kind}${snap.build ? ` · ${list(snap.build.order).length} points` : ''}`;
    $('#import-note').textContent =
      snap.kind === 'library'
        ? 'Profiles merge without replacing existing profiles; exact duplicates are skipped. Character workspaces and simulation settings also sync. Checked above: incoming class drafts replace drafts for those classes. Export your library first for a backup.'
        : snap.kind === 'stats'
          ? 'Loads simulation stats only. Your talents, race and level stay as they are.'
          : 'Loads the shared class, race, level and talent order. Character snapshots also load the central stat/equipment workspace. Undo restores talents; character stats stay separate.';
  } catch (e) {
    load.disabled = true;
    $('#import-drafts-label').hidden = true;
    $('#import-preview').textContent = input ? e.message : 'Paste a string to preview it.';
    $('#import-note').textContent = '';
  }
}
function showShare(kind = 'build', context = {}) {
  openDialog(
    'Copy & share',
    `<p class="muted">These strings work in both the addon and PWA. Friends need the same data version for talent builds. Stats-only strings keep their current talents.</p><label class="field-label" for="share-kind">What to copy</label><select id="share-kind">${[
      ['build', 'Talent build + ordered points'],
      ['character', 'Character: level + talents + stats + gear'],
      ['stats', 'Character stats + gear (or temporary skill inputs)'],
      ['library', 'Whole library: builds + branches + drafts'],
    ]
      .map(
        ([id, title]) => `<option value="${id}" ${id === kind ? 'selected' : ''}>${title}</option>`
      )
      .join(
        ''
      )}</select><label class="field-label" for="share-code">Sharing string</label><textarea id="share-code" rows="5" readonly spellcheck="false"></textarea><p class="muted" id="share-note"></p><div class="dialog-actions">${btn('Copy string', 'copy-code', '', 'primary')}${btn('Save to file', 'download-code')}${btn('Import a string', 'import')}</div><p class="muted">In-game clickable whispers need the WoW addon. Paste these strings into any messenger, or choose Import in the other version.</p>`
  );
  modal.shareContext = context;
  refreshShare();
}
function refreshShare() {
  try {
    const kind = $('#share-kind').value;
    const code = engine.call('export', { kind, ...modal.shareContext });
    $('#share-code').value = code;
    $('#share-note').textContent =
      kind === 'library'
        ? `Full library export · ${code.length.toLocaleString()} characters. Includes checkpoints, all class drafts, undo/redo and simulation stats. Native window settings and received whispers stay on their own device.`
        : kind === 'stats'
          ? 'Character exports include the central workspace and equipment. Temporary skill inputs can be pasted inside Simulator without changing Character. Live captures retain reported power/crit by school.'
          : 'The exported level is the displayed level. Preview mode exports only the displayed talent prefix.';
  } catch (e) {
    toast(e.message, true);
  }
}
async function copyCode() {
  const field = $('#share-code');
  try {
    await navigator.clipboard.writeText(field.value);
    toast('Copied. Paste into the addon or another device.');
  } catch {
    field.focus();
    field.select();
    toast('Select all is ready. Press Ctrl+C / Cmd+C, or use your phone’s Copy command.');
  }
}
function download(code, name) {
  const a = document.createElement('a');
  const url = URL.createObjectURL(new Blob([code], { type: 'text/plain;charset=utf-8' }));
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function showLibrary() {
  const profiles = list(state.profileOrder).map((id) => state.profiles[id]);
  openDialog(
    'Library & sync',
    `<p class="muted">Saved builds, immutable checkpoints and alternate branches. Your class drafts autosave separately.</p><div class="dialog-actions">${btn('Export whole library', 'export-library', '', 'primary')}${btn('Import / merge library', 'import')}${btn('Open sharing file', 'open-file')}</div><input id="sharing-file" type="file" accept=".txt,.ftc,text/plain" hidden><div class="library-list">${profiles.length ? profiles.map((p) => `<article class="library-card"><div><h3>${esc(p.name)}</h3><p class="muted">${esc(catalog.classes[p.nodes[list(p.order)[0]].build.classID].name)} · ${list(p.order).length} checkpoints</p></div><div>${btn('Open', 'load', `data-profile="${p.id}" data-node="${list(p.order).at(-1)}"`, 'primary')}${btn('Rename', 'rename', `data-profile="${p.id}"`)}${btn('Delete', 'delete-profile', `data-profile="${p.id}"`, 'danger')}</div></article>`).join('') : '<p class="empty">No saved profiles yet. Choose Save build to start one.</p>'}</div><p class="callout">To sync everything: Export whole library → copy the string or save a file → open Character in the addon or Import in this app → merge. Profiles with identical contents are skipped. Export before replacing class drafts.</p>`,
    true
  );
}
function showSave(checkpoint = false) {
  openDialog(
    checkpoint ? 'Save a checkpoint' : 'Save a named build',
    `<p class="muted">${checkpoint ? 'This checkpoint branches from the selected node. Older checkpoints stay intact.' : 'Keeps this allocation and its exact leveling order. Add checkpoints as you explore.'}</p><label class="field-label" for="save-title">${checkpoint ? 'Checkpoint title' : 'Build name'}</label><input id="save-title" maxlength="48" value="${checkpoint ? '' : esc(state.build.name === 'Untitled build' ? '' : state.build.name)}" placeholder="${checkpoint ? 'Level 30 · alternate route' : 'My leveling build'}"><div class="dialog-actions">${btn('Save', checkpoint ? 'confirm-checkpoint' : 'confirm-save', '', 'primary')}${btn('Cancel', 'close')}</div>`
  );
  $('#save-title').focus();
}
function confirmDialog(title, message, action, data = '') {
  openDialog(
    title,
    `<p class="callout">${esc(message)}</p><div class="dialog-actions">${btn('Delete', action, data, 'danger')}${btn('Cancel', 'close')}</div>`
  );
}
function showRaces() {
  openDialog(
    'Race & class atlas',
    `<p class="muted">Choose an available combination. Existing class drafts are kept. Scroll the table sideways on a phone.</p><div class="table-scroll"><table><thead><tr><th>Race</th>${list(
      catalog.classOrder
    )
      .map((id) => `<th>${img(catalog.classes[id].icon)}${esc(catalog.classes[id].name)}</th>`)
      .join('')}</tr></thead><tbody>${Object.values(catalog.races)
      .map(
        (r) =>
          `<tr><th><span class="${r.faction === 'Horde' ? 'horde' : 'alliance'}">${esc(r.name)}</span></th>${list(
            catalog.classOrder
          )
            .map(
              (id) =>
                `<td>${list(catalog.classes[id].races).includes(r.id) ? btn('Select', 'race-class', `data-class="${id}" data-race="${r.id}" aria-label="${esc(r.name)} ${esc(catalog.classes[id].name)}"`, state.view.raceID === r.id && state.view.classID === Number(id) ? 'active' : '') : '—'}</td>`
            )
            .join('')}</tr>`
      )
      .join('')}</tbody></table></div>`,
    true
  );
}
function showHelp() {
  openDialog(
    'A quick guide',
    `<div class="guide-grid"><article><h3>Plan the journey</h3><p>On desktop, click a talent to add a point; right-click removes one. Shift fills or clears its ranks. On phones, tap a talent to read it, then use Add / Remove. Keyboard users can focus a talent and press Enter to inspect it.</p><p>Rows need five points per tier in the same tree. Prerequisites, maximum ranks and level budgets come from the same engine as the addon. Auto raises and lowers your level as you spend or remove points.</p></article><article><h3>Find the interactions</h3><p>Search skills and talents by name or description. Hover a skill for temporary highlights, or check boxes to keep several highlights. Clear highlights unchecks every selection. Open a skill for all ranks, unlock levels and talent links.</p><p>Character keeps a central stat and equipment plan per class. Simulator inherits it, shows only applicable inputs, and keeps experiments temporary. Expected totals average crits and failed casts. Open the calculation and accuracy details for formulas, sources and missing mechanics.</p></article><article><h3>Checkpoint and branch</h3><p>Save a build, then save titled checkpoints. Open an old node to grow a new branch. Deleting a node deletes its descendants; your current allocation stays here. Undo / Redo keep 100 edits per class.</p><p>Tap a talent-order step to preview that level. Full build exits preview. Branch here turns that prefix into a draft you can checkpoint.</p></article><article><h3>Share & sync</h3><p>FT1 shares talents and their order. FC1 adds level, character stats and equipment. FS2 shares character stats and gear, or temporary skill inputs; FS1 is still supported. FL1 transfers your full build library, branches and class drafts. Open Character in the addon to capture the logged-in character.</p><p>A browser cannot read a running WoW client. Copy the capture in the addon and paste it here. Original live spending order is unavailable; live imports derive a legal order.</p></article><article><h3>Offline & install</h3><p>After the offline status says Ready, the calculator works without a connection. Install from the app button or your browser menu. iPhone/iPad: Safari → Share → Add to Home Screen. Windows/Linux/Android: an install-capable browser can create an app shortcut.</p><p>Browser saves stay on this device. Export your library before clearing website data or switching browsers. Update prompts preserve your local library.</p></article><article><h3>Data notes</h3><p>Captured Forever ${esc(catalog.meta.build)} / ${esc(catalog.meta.buildNumber)}, ${esc(catalog.meta.generatedAt.slice(0, 10))}. Missing descriptions are marked. Simulator uses a separately dated client-effect snapshot and reviewed developer corrections. Unknown scaling is marked as unverified and contributes no power until you supply a coefficient. Reference base stats are estimates; native live captures retain reported totals.</p><p>Class talents, legacy perks and pet reference tables have separate systems. Perks are a read-only atlas, not part of the 51 talent points.</p></article></div>`,
    true
  );
}
const simulator = createSimulatorUI({
  engine: () => engine,
  state: () => state,
  openDialog,
  showShare,
  showImport,
  persist,
  toast,
});
let pet = { mode: 'skills', family: '', query: '', page: 1 };
function showPets() {
  openDialog(
    'Hunter pet atlas',
    `<p class="muted">Rank levels and tameable beasts from the captured dataset.</p><div class="pet-filters"><input id="pet-search" type="search" value="${esc(pet.query)}" placeholder="Search pet skills or beasts…" aria-label="Search pets"><select id="pet-family" aria-label="Pet family"><option value="">All families</option>${list(
      catalog.pets.families
    )
      .map(
        (f) =>
          `<option value="${f.id}" ${pet.family === String(f.id) ? 'selected' : ''}>${esc(f.name)}</option>`
      )
      .join(
        ''
      )}</select><select id="pet-mode" aria-label="Pet atlas category"><option value="skills" ${pet.mode === 'skills' ? 'selected' : ''}>Pet skills</option><option value="beasts" ${pet.mode === 'beasts' ? 'selected' : ''}>Tameable beasts</option></select></div><div id="pet-results"></div><div class="dialog-actions">${btn('Previous', 'pet-prev')}${btn('Next', 'pet-next')}</div>`,
    true
  );
  renderPets();
}
function renderPets() {
  const source = list(pet.mode === 'skills' ? catalog.pets.skills : catalog.pets.tameable);
  const matches = source.filter(
    (e) =>
      (!pet.family ||
        String(e.family) === pet.family ||
        list(e.families).some((id) => String(id) === pet.family)) &&
      `${e.name} ${e.text || ''}`.toLowerCase().includes(pet.query.toLowerCase())
  );
  const pages = Math.max(1, Math.ceil(matches.length / 30));
  pet.page = Math.max(1, Math.min(pet.page, pages));
  $('#pet-results').innerHTML =
    `<p class="muted">${matches.length} matches · page ${pet.page} / ${pages}</p>${
      matches
        .slice((pet.page - 1) * 30, pet.page * 30)
        .map(
          (e) =>
            `<article class="rank-card"><div><b>${esc(e.name)}</b><span>${pet.mode === 'skills' ? `Lv. ${e.level} · ${esc(e.label || 'Passive / unranked')}` : `${e.minlevel ? `Lv. ${e.minlevel}–${e.maxlevel || e.minlevel}` : 'Level unrecorded'} · ${esc(list(catalog.pets.families).find((f) => f.id === e.family)?.name || '')}`}</span></div><p>${
              pet.mode === 'skills'
                ? esc(e.text || 'No description recorded in the snapshot.')
                : `${esc(
                    list(e.location)
                      .map((id) => catalog.pets.zones[id] || `Zone ${id}`)
                      .join(', ') || 'Location unrecorded'
                  )} · Creature ${e.id}`
            }</p></article>`
        )
        .join('') || '<p class="empty">No matches.</p>'
    }`;
  $('[data-action="pet-prev"]').disabled = pet.page <= 1;
  $('[data-action="pet-next"]').disabled = pet.page >= pages;
}
function showPerks() {
  openDialog(
    'Forever perk reference',
    `<p class="callout">Legacy perks use their own currency and a 16-point budget. This is a read-only reference; class talent builds remain separate.</p><div class="perk-trees">${list(
      catalog.perks
    )
      .map(
        (t) =>
          `<section><h3>${esc(t.name)}</h3><p class="muted">${esc(t.blurb)}</p>${list(t.nodes)
            .map(
              (n) =>
                `<details><summary>${img(n.icon)}${esc(n.name)}</summary><p class="muted">${n.max} ranks · source gate ${n.gate} perk points</p>${list(
                  n.ranks
                )
                  .map((text, i) => `<p><b>Rank ${i + 1}</b><br>${esc(text)}</p>`)
                  .join('')}</details>`
            )
            .join('')}</section>`
      )
      .join('')}</div>`,
    true
  );
}
function changeContext() {
  selected.clear();
  hovered = null;
  treeTab = 0;
}
// Event delegation survives rerenders; build changes go through the shared engine.
document.addEventListener('click', async (event) => {
  const node = event.target.closest('[data-action]');
  if (!node) {
    const t = event.target.closest('[data-talent]');
    if (t) {
      const id = Number(t.dataset.talent);
      if (event.ctrlKey || event.metaKey) {
        const names = list(engine.call('talentSkills', { id }));
        if (names.length === 1) showSkill(names[0]);
        else showTalent(id);
      } else if (
        event.detail === 0 ||
        matchMedia('(max-width: 1050px), (pointer: coarse)').matches ||
        state.preview !== undefined
      )
        showTalent(id);
      else act('add', { id, fill: event.shiftKey });
    }
    const s = event.target.closest('[data-skill]');
    if (s) showSkill(s.dataset.skill);
    return;
  }
  const a = node.dataset.action,
    id = Number(node.dataset.id),
    profileID = node.dataset.profile,
    nodeID = Number(node.dataset.node);
  try {
    if (simulator.action(a, node)) return;
    switch (a) {
      case 'close':
        closeDialog();
        break;
      case 'recovery':
        download(
          unreadableSave || localStorage.getItem(KEY) || '',
          'ForeverTalents-original-browser-save.json'
        );
        break;
      case 'class':
        changeContext();
        act('switch', { classID: id });
        break;
      case 'auto':
        act('auto', { enabled: !state.auto });
        break;
      case 'level-down':
        act('level', { level: state.build.level - 1 });
        break;
      case 'level-up':
        act('level', { level: state.build.level + 1 });
        break;
      case 'undo':
      case 'redo':
        act(a);
        break;
      case 'reset':
        act('reset');
        break;
      case 'reset-tree':
        act('reset', { treeID: id });
        break;
      case 'tree-tab':
        treeTab = Number(node.dataset.index);
        render();
        break;
      case 'panel':
        panel = node.dataset.panel;
        render();
        window.scrollTo({ top: 0, behavior: 'smooth' });
        break;
      case 'clear-highlights':
        selected.clear();
        hovered = null;
        renderSkills();
        paintHighlights();
        break;
      case 'racial':
      case 'related-skill':
        showSkill(node.dataset.name);
        break;
      case 'locate': {
        const t = talent(id);
        treeTab = list(cls().trees).findIndex((tr) => list(tr.talents).some((n) => n.id === id));
        panel = 'trees';
        closeDialog();
        render();
        $(`[data-talent="${id}"]`).focus();
        showTalent(id);
        break;
      }
      case 'talent-add':
      case 'talent-fill':
        if (act('add', { id, fill: a === 'talent-fill' }) !== null) showTalent(id);
        break;
      case 'talent-remove':
      case 'talent-clear':
        if (act('remove', { id, all: a === 'talent-clear' }) !== null) showTalent(id);
        break;
      case 'save':
        showSave();
        break;
      case 'checkpoint':
        showSave(true);
        break;
      case 'confirm-save':
      case 'confirm-checkpoint':
        if (
          act(a === 'confirm-save' ? 'save' : 'checkpoint', { title: $('#save-title').value }) !==
          null
        )
          closeDialog();
        break;
      case 'load':
        if (act('load', { profileID, nodeID }) !== null) {
          changeContext();
          closeDialog();
          panel = 'builds';
          render();
        }
        break;
      case 'preview':
        act('preview', { count: Number(node.dataset.count) });
        break;
      case 'full':
        act('preview');
        break;
      case 'branch':
        if (act('branch') !== null) showSave(!!state.activeProfile);
        break;
      case 'reorder':
        act('reorder', { from: Number(node.dataset.from), to: Number(node.dataset.to) });
        break;
      case 'delete-node': {
        const sub = engine.call('subtree', { profileID, nodeID });
        confirmDialog(
          'Delete checkpoint branch?',
          `Deletes ${sub.count} checkpoint${sub.count === 1 ? '' : 's'}, including every descendant. Your current working allocation is kept. This deletion cannot be undone.`,
          'confirm-delete-node',
          `data-profile="${profileID}" data-node="${nodeID}"`
        );
        break;
      }
      case 'confirm-delete-node':
        if (act('deleteNode', { profileID, nodeID }) !== null) closeDialog();
        break;
      case 'delete-profile':
        confirmDialog(
          'Delete saved profile?',
          `Deletes ${state.profiles[profileID].name} and all its checkpoints. The working allocation stays here. This cannot be undone.`,
          'confirm-delete-profile',
          `data-profile="${profileID}"`
        );
        break;
      case 'confirm-delete-profile':
        if (act('deleteProfile', { profileID }) !== null) showLibrary();
        break;
      case 'rename':
        openDialog(
          'Rename build',
          `<label class="field-label" for="rename-title">Profile name</label><input id="rename-title" maxlength="48" value="${esc(state.profiles[profileID].name)}"><div class="dialog-actions">${btn('Rename', 'confirm-rename', `data-profile="${profileID}"`, 'primary')}</div>`
        );
        break;
      case 'confirm-rename':
        if (act('rename', { profileID, title: $('#rename-title').value }) !== null) showLibrary();
        break;
      case 'import':
        showImport();
        break;
      case 'import-load':
        if (
          act('import', {
            code: $('#import-code').value,
            includeDrafts: $('#import-drafts').checked,
          }) !== null
        ) {
          changeContext();
          closeDialog();
          render();
          toast(state.message || 'Imported.');
        }
        break;
      case 'share':
        showShare();
        break;
      case 'copy-code':
        await copyCode();
        break;
      case 'download-code':
        download(
          $('#share-code').value,
          `ForeverTalents-${$('#share-kind').value}-${new Date().toISOString().slice(0, 10)}.txt`
        );
        break;
      case 'library':
        showLibrary();
        break;
      case 'export-library':
        showShare('library');
        break;
      case 'open-file':
        $('#sharing-file').click();
        break;
      case 'races':
        showRaces();
        break;
      case 'race-class':
        changeContext();
        act('switch', { classID: Number(node.dataset.class) });
        act('race', { raceID: Number(node.dataset.race) });
        closeDialog();
        break;
      case 'help':
        showHelp();
        break;
      case 'pets':
        showPets();
        break;
      case 'perks':
        showPerks();
        break;
      case 'pet-prev':
        pet.page--;
        renderPets();
        break;
      case 'pet-next':
        pet.page++;
        renderPets();
        break;
      case 'install':
        if (installPrompt) {
          await installPrompt.prompt();
          await installPrompt.userChoice;
          installPrompt = null;
        } else
          openDialog(
            'Install Forever Talents',
            `<p>Android / Windows / Linux: open your browser’s menu and choose <b>Install app</b> or <b>Add to Home Screen</b> when supported.</p><p>iPhone / iPad: open this page in <b>Safari</b>, tap <b>Share</b>, then <b>Add to Home Screen</b>.</p><p class="muted">Installation requires HTTPS (localhost works for development). Wait for Ready offline before using without a connection.</p>`
          );
        break;
      case 'update':
        persist();
        registration?.waiting?.postMessage({ type: 'SKIP_WAITING' });
        break;
    }
  } catch (e) {
    toast(e.message, true);
  }
});
document.addEventListener('contextmenu', (event) => {
  const t = event.target.closest('[data-talent]');
  if (t) {
    event.preventDefault();
    act('remove', { id: Number(t.dataset.talent), all: event.shiftKey });
  }
});
document.addEventListener('input', (event) => {
  const t = event.target;
  if (t.id === 'skill-search') {
    skillQuery = t.value;
    renderSkills();
  }
  if (t.id === 'talent-search') {
    talentQuery = t.value;
    const access = engine.call('talents', { query: talentQuery });
    for (const n of document.querySelectorAll('[data-talent]'))
      n.classList.toggle('unmatched', !access[n.dataset.talent].match);
  }
  if (t.id === 'import-code') previewImport();
  if (t.id === 'pet-search') {
    pet.query = t.value;
    pet.page = 1;
    renderPets();
  }
  try {
    simulator.inputEvent(t);
  } catch (e) {
    toast(e.message, true);
  }
});
document.addEventListener('change', async (event) => {
  const t = event.target;
  try {
    if (simulator.changeEvent(t)) return;
  } catch (e) {
    toast(e.message, true);
    return;
  }
  if (t.id === 'race') {
    for (const [key, s] of selected) if (s.kind === 'racial') selected.delete(key);
    act('race', { raceID: Number(t.value) });
  }
  if (t.id === 'level') act('level', { level: Number(t.value) });
  if (t.id === 'skill-filter') {
    skillFilter = t.value;
    renderSkills();
  }
  if (t.dataset.skillCheck) {
    const s = engine.call('skill', { name: t.dataset.skillCheck });
    if (t.checked) selected.set(skillKey(s), s);
    else selected.delete(skillKey(s));
    renderSkills();
    for (const n of modal.querySelectorAll('[data-skill-check]'))
      n.checked = selected.has(skillKey(s));
    paintHighlights();
  }
  if (t.id === 'share-kind') refreshShare();
  if (t.id === 'pet-family' || t.id === 'pet-mode') {
    pet[t.id === 'pet-family' ? 'family' : 'mode'] = t.value;
    pet.page = 1;
    renderPets();
  }
  if (t.id === 'sharing-file' && t.files?.[0]) {
    const f = t.files[0];
    if (f.size > 3145728) {
      toast('Sharing files must be at most 3 MB.', true);
      return;
    }
    showImport(await f.text());
  }
});
document.addEventListener('mouseover', (event) => {
  if (matchMedia('(max-width: 1050px), (pointer: coarse)').matches) return;
  const s = event.target.closest('[data-skill]');
  if (s) {
    hovered = engine.call('skill', { name: s.dataset.skill });
    paintHighlights();
  }
  const t = event.target.closest('[data-talent]');
  if (t && !modal.open) {
    const tip = $('#tooltip');
    tip.innerHTML = description(talent(t.dataset.talent));
    tip.hidden = false;
    const rect = t.getBoundingClientRect();
    tip.style.left = `${Math.min(innerWidth - 344, Math.max(8, rect.right + 12))}px`;
    tip.style.top = `${Math.min(innerHeight - tip.offsetHeight - 8, Math.max(8, rect.top))}px`;
  }
});
document.addEventListener('mouseout', (event) => {
  if (event.target.closest('[data-skill]') && !event.relatedTarget?.closest('[data-skill]')) {
    hovered = null;
    paintHighlights();
  }
  if (event.target.closest('[data-talent]') && !event.relatedTarget?.closest('[data-talent]'))
    $('#tooltip').hidden = true;
});
modal.addEventListener('close', () => {
  hovered = null;
  paintHighlights();
  if (modal.returnSelector) {
    const target = app.querySelector(modal.returnSelector);
    if (target && target.getClientRects().length) target.focus({ preventScroll: true });
  }
});
document.addEventListener('keydown', (event) => {
  if (
    (event.ctrlKey || event.metaKey) &&
    !['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target.tagName) &&
    !modal.open
  ) {
    if (event.key.toLowerCase() === 'z') {
      event.preventDefault();
      act(event.shiftKey ? 'redo' : 'undo');
    }
    if (event.key.toLowerCase() === 'y') {
      event.preventDefault();
      act('redo');
    }
  }
  if (event.key === 'Enter' && event.target.id === 'save-title')
    $('[data-action="confirm-save"],[data-action="confirm-checkpoint"]').click();
});
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  installPrompt = event;
});
window.addEventListener('online', () => {
  toast('Back online. Checking for updates…');
  registration?.update().catch(() => {});
});
async function offline() {
  if (!('serviceWorker' in navigator) || !import.meta.env.PROD) {
    status = import.meta.env.PROD ? 'Offline unavailable in this browser' : 'Development preview';
    render();
    return;
  }
  try {
    registration = await navigator.serviceWorker.register(new URL('sw.js', document.baseURI), {
      scope: new URL('./', document.baseURI).pathname,
    });
    function waiting() {
      if (registration.waiting) {
        $('#update-banner').hidden = false;
      }
    }
    function watch() {
      const worker = registration.installing;
      worker?.addEventListener('statechange', () => {
        if (worker.state === 'installed') setTimeout(waiting, 0);
      });
      waiting();
    }
    registration.addEventListener('updatefound', watch);
    watch();
    await navigator.serviceWorker.ready;
    status = 'Ready offline';
    render();
    waiting();
    let refreshed = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!refreshed) {
        refreshed = true;
        location.reload();
      }
    });
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) registration.update().catch(() => {});
    });
  } catch (e) {
    status = 'Offline setup unavailable';
    render();
    toast(
      'Offline files could not be cached. Keep this page online and export saves before clearing browser data.',
      true
    );
  }
}
try {
  let saved;
  try {
    unreadableSave = localStorage.getItem(KEY) || '';
    if (unreadableSave) saved = JSON.parse(unreadableSave);
  } catch {
    storageBlocked = true;
    toast(
      'Saved browser data could not be read. Autosaving is paused to preserve it; More contains the recovery download.',
      true
    );
  }
  engine = await createEngine(saved);
  state = engine.initial;
  catalog = engine.call('catalog');
  render();
  if (state.readOnly) toast(state.message, true);
  persist();
  offline();
} catch (e) {
  app.innerHTML = `<div class="loading"><h1>Calculator could not start</h1><p>${esc(e.message)}</p><p>Reload while online to finish downloading the engine. Your saved library is kept.</p><button onclick="location.reload()">Reload</button></div>`;
}
