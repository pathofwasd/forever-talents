import './style.css';
import { createEngine, list } from './engine.js';
import { createSimulatorUI } from './simulator.js';
import { createUpdateMonitor } from './updates.js';
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
  selectionColors = new Map(),
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
  registration,
  updateMonitor,
  updateMessage = '',
  updateBusy = false;
let graphView = { profileID: null, activeID: null, left: 0, top: 0, width: 0 };
const modal = $('#modal'),
  talentSheet = $('#talent-sheet'),
  app = $('#app');
let sheetTalent = null;
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
  if (previous.view.classID !== state.view.classID) changeContext(true);
  else if (previous.view.raceID !== state.view.raceID) {
    for (const [key, skill] of selected)
      if (skill.kind === 'racial') {
        selected.delete(key);
        selectionColors.delete(key);
      }
    if (hovered?.kind === 'racial') hovered = null;
  }
  persist();
  render();
}
function act(name, payload = {}) {
  try {
    const value = engine.call(name, payload);
    update();
    if (['remove', 'load', 'updateCheckpoint'].includes(name) && state.message)
      toast(state.message);
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
  const choices = [...selected.values(), ...(hovered ? [hovered] : [])]
    .filter((skill) => !state.simpleView || skill.kind !== 'racial')
    .map((skill) => ({ skill, color: selectionColors.get(skillKey(skill)) || 1 }));
  return engine.call('highlights', { selections: choices });
}
function highlightStyle(skill) {
  const index = selectionColors.get(skillKey(skill));
  const color = index && catalog.highlightPalette[index];
  return color
    ? `style="accent-color:#${color.hex};--highlight-color:#${color.hex}" title="${esc(color.name)} highlight"`
    : '';
}
function skillKey(s) {
  return s?.name ? `${s.kind}:${s.name}` : null;
}
function highlightControl(control) {
  if (!control) return;
  hovered = control.dataset.skill
    ? engine.call('skill', { name: control.dataset.skill })
    : { related: [{ id: Number(control.dataset.highlightTalent) }] };
  paintHighlights();
}
function currentSkillFilter() {
  if (skillFilter === 'needsTraining' && !state.checkTraining) return 'all';
  return state.simpleView && !['now', 'trained', 'needsTraining'].includes(skillFilter)
    ? 'all'
    : skillFilter;
}
function checkpointActions() {
  const blocked = state.readOnly || state.preview !== undefined;
  return state.activeProfile
    ? btn('Update checkpoint', 'update-checkpoint', '', 'primary', blocked || !state.dirty) +
        btn('Save as new checkpoint', 'checkpoint', '', '', blocked)
    : btn('Save build', 'save', '', 'primary', blocked);
}
function activeCheckpointBar(hidden = false) {
  const profile = state.profiles[state.activeProfile],
    node = profile?.nodes[state.activeNode];
  return `<section class="checkpoint-status" data-full-view aria-label="Active checkpoint" ${hidden ? 'hidden' : ''}><div class="checkpoint-current"><span class="eyebrow">${node ? 'Active checkpoint' : 'No saved checkpoint'}</span><strong>${esc(node?.title || state.build.name)}</strong><small>${node ? esc(profile.name) + ' · ' : ''}<span class="checkpoint-save-state ${node && state.dirty ? 'unsaved' : ''}">${node ? (state.dirty ? 'Unsaved changes' : 'Saved') : 'Save build to start checkpoints'}</span></small></div><div class="checkpoint-status-actions">${checkpointActions()}</div></section>`;
}
function render() {
  // Keep the viewport stable while replacing planner content or updating ranks.
  const viewport = { x: window.scrollX, y: window.scrollY };
  const graphScroll = $('.graph-scroll');
  if (graphScroll?.clientHeight) {
    graphView.left = graphScroll.scrollLeft;
    graphView.top = graphScroll.scrollTop;
  }
  const focus = document.activeElement;
  const key = focus?.id;
  const start = focus?.selectionStart,
    end = focus?.selectionEnd;
  const c = cls(),
    race = catalog.races[state.view.raceID],
    allTrees = list(c.trees),
    points = order().length;
  app.dataset.simpleView = String(state.simpleView);
  document.body.dataset.simulationEnabled = String(state.simulationEnabled);
  app.innerHTML = `<header class="topbar"><a class="brand" href="./" aria-label="Forever Talents home"><img src="./icon.svg" alt="" width="36" height="36"><span>Forever <strong>Talents</strong><small><span class="desktop-brand">PLAN YOUR JOURNEY</span><span class="mobile-brand">${esc(status)}</span></small></span></a><div class="top-actions"><span class="connection" id="offline-status">${esc(status)}</span>${btn('Install', 'install', '', 'quiet')}${btn('<svg class="character-button-icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="7" r="4"/><path d="M4 22v-3a8 8 0 0 1 16 0v3"/></svg><span class="character-button-label">Character</span>', 'character-sheet', 'data-full-view data-simulation-feature aria-label="Character" title="Character stats and equipment · experimental"', 'quiet character-button')}${btn('Guide', 'help', '', 'quiet')}${btn('Import', 'import', 'data-full-view')}${btn('Share', 'share', 'data-full-view', 'primary')}</div></header>
  <div id="update-banner" class="update-banner" hidden>A new version is ready. Your saved builds will be kept. ${btn('Update now', 'update', '', 'primary')}</div>
  <main><div class="view-options">${btn('Settings', 'settings', '', 'quiet view-settings')}<label class="view-toggle" title="Show class, talent trees and skill levels; keep your saved builds and character settings."><input id="simple-view" type="checkbox" ${state.simpleView ? 'checked' : ''} aria-describedby="view-caption"><span>Simple view</span></label><span id="view-caption" class="sr-only">Hide extra tools without changing your builds. Turn off to restore the full view.</span></div>${storageBlocked || state.readOnly ? `<aside class="recovery-banner callout">Saving is paused to preserve unreadable or newer browser data. ${btn('Download original saved data', 'recovery')}</aside>` : ''}<section class="controls" aria-label="Character and build controls"><div class="class-choices" aria-label="Class">${list(
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
    .join('')}</div><label class="race-select" data-full-view>Race<select id="race">${list(c.races)
    .map(
      (id) =>
        `<option value="${id}" ${Number(id) === state.view.raceID ? 'selected' : ''}>${esc(catalog.races[id].name)}</option>`
    )
    .join(
      ''
    )}</select></label>${btn('Race atlas', 'races', 'data-full-view', 'quiet')}<div class="level-controls"><label for="level">${state.auto ? 'Level' : 'Target'}</label>${btn('−', 'level-down', '', 'square', state.auto || state.preview !== undefined)}<input id="level" type="number" min="1" max="60" value="${state.viewLevel}" aria-label="Character target level" ${state.auto || state.preview !== undefined ? 'disabled' : ''}>${btn('+', 'level-up', '', 'square', state.auto || state.preview !== undefined)}${btn('Auto', 'auto', `aria-pressed="${state.auto}"`, state.auto ? 'active' : '')}</div><div class="edit-controls">${btn('↶ Undo', 'undo', '', '', !state.undo)}${btn('↷ Redo', 'redo', '', '', !state.redo)}${btn('Reset', 'reset')}</div></section>
  <section class="hero"><div>${img(c.icon, 'hero-icon')}<div><p class="eyebrow" data-full-view>${esc(race.name)} · ${esc(race.faction)}</p><h1>${esc(c.name)} <span data-full-view>${esc(state.build.name)}</span></h1><p class="spec-counts">${allTrees.map((t) => `<span class="spec-item">${esc(t.name)} <b>${state.treeCounts[t.id] || 0}</b></span>`).join('<span class="spec-divider">/</span>')}</p></div></div><div class="hero-level"><strong>Level ${state.viewLevel}</strong><span>${points} / ${state.budget} points · ${Math.max(0, state.budget - points)} left</span><small>${state.preview !== undefined ? 'Leveling preview · editing paused' : state.auto ? 'Auto follows spent talents' : `Spent talents require level ${state.requiredLevel}`}</small></div></section>
  ${state.preview !== undefined ? `<aside class="preview-banner">Previewing point ${state.preview} of ${list(state.build.order).length}. ${btn('Full build', 'full')}${btn('Branch here', 'branch', '', 'primary')}</aside>` : ''}
  ${activeCheckpointBar(panel === 'builds')}<nav class="workspace-nav" data-full-view aria-label="Planner workspace">${btn('Talent trees', 'panel', `data-panel="trees" aria-pressed="${panel !== 'builds'}"`, panel !== 'builds' ? 'active' : '')}${btn('Checkpoints & order', 'panel', `data-panel="builds" aria-pressed="${panel === 'builds'}"`, panel === 'builds' ? 'active' : '')}</nav>
  ${state.repair ? `<aside class="repair-notice" role="status"><strong>Older build needs repair</strong><p>${esc(state.repair)} Impale now requires 3/3 Deep Wounds before it in the point order. Add the missing points, move them before Impale in Checkpoints & order, or remove Impale. Existing checkpoints and the original allocation are kept.</p>${btn('Copy original build', 'share-original')}</aside>` : ''}
  <div class="workspace" data-panel="${panel}"><aside class="panel skills-panel" aria-label="Skills and ranks"><div class="section-heading"><h2>Skills & ranks</h2><span>${state.viewLevel} LV</span></div><p class="muted">${state.simpleView ? 'Check to keep colored talent highlights. Click a skill for unlock and upgrade levels.' : 'Check to keep talent highlights.'}</p><input id="skill-search" type="search" placeholder="Search skills or effects…" value="${esc(skillQuery)}" aria-label="Search skills"><select id="skill-filter" aria-label="Skill category">${(state.simpleView
    ? [
        ['all', 'All class skills'],
        ['now', 'Available at this level'],
        ['trained', 'Trained on captured character'],
        ...(state.checkTraining ? [['needsTraining', 'Needs training']] : []),
      ]
    : [
        ['all', 'All skills & racials'],
        ['now', 'Available at this level'],
        ['trained', 'Trained on captured character'],
        ...(state.checkTraining ? [['needsTraining', 'Needs training']] : []),
        ['talent', 'Unlocked by talents'],
        ['racial', 'Racial traits'],
      ]
  )
    .map(
      ([key, label]) =>
        `<option value="${key}" ${currentSkillFilter() === key ? 'selected' : ''}>${label}</option>`
    )
    .join(
      ''
    )}</select><label class="training-toggle" title="Compare the displayed level and talents with your last imported spellbook. Re-import after learning skills."><input id="check-training" type="checkbox" ${state.checkTraining ? 'checked' : ''}>Compare imported character</label><button id="training-summary" type="button" class="training-summary" data-action="needs-training" hidden></button><div class="skill-list" id="skill-list"></div>${btn('Clear highlights', 'clear-highlights', '', 'wide')}</aside>
  <section class="talents-panel" aria-label="Talent trees"><div class="talent-heading"><h2>Talent trees</h2><div class="talent-transfer-actions">${btn('Copy talents', 'copy-talents', 'title="Copy class and ordered talent points only"')}${btn('Paste talents', 'paste-talents', '', '', state.preview !== undefined)}</div><input id="talent-search" type="search" placeholder="Search talents or effects…" value="${esc(talentQuery)}" aria-label="Search talents"></div><nav class="tree-tabs" aria-label="Talent tree">${allTrees.map((t, i) => btn(`${esc(t.name)} <b>${state.treeCounts[t.id] || 0}</b>`, 'tree-tab', `data-index="${i}" aria-pressed="${i === treeTab}"`, i === treeTab ? 'active' : '')).join('')}</nav><div class="trees">${allTrees.map((tree, i) => renderTree(tree, i)).join('')}</div><p class="tree-hint"><span class="desktop-hint">Click +1 · right-click −1 · Shift fills / clears · Alt: details</span><span class="touch-hint">Tap a talent for details; use + / − while the tree stays in view.</span></p><div class="racials" data-full-view><h2>Racial traits</h2><div id="racial-list"></div></div></section>
  <section class="panel builds-panel" data-full-view aria-label="Checkpoint workspace"><div class="section-heading"><h2>Checkpoints</h2><span class="saved-dot">${state.readOnly || storageBlocked ? 'Saving paused' : ''}</span></div>${activeCheckpointBar()}<div class="build-actions">${btn('New build', 'save', '', 'quiet')}${btn('Share checkpoints', 'share-profile', `data-profile="${state.activeProfile || ''}"`, '', !state.activeProfile)}${btn('Library & sync', 'library')}</div><div class="checkpoint-content"><div id="history-graph"></div><section class="order-panel" aria-label="Talent order"><div class="section-heading order-heading"><h3>Talent order</h3><span>${list(state.build.order).length} ${list(state.build.order).length === 1 ? 'step' : 'steps'}</span></div><div class="order-list">${renderOrder()}</div></section></div></section>
  <section class="panel more-panel" data-full-view><h2>Atlas & tools</h2><p class="muted">Your whole library lives on this device. Use Library & sync to move it between devices and the addon.</p><div class="tool-grid">${btn('Settings', 'settings')}${btn('Library & sync', 'library')}${btn('Character & simulator (experimental)', 'character-sheet', 'data-simulation-feature')}${btn('Race & class atlas', 'races')}${btn('Hunter pet atlas', 'pets')}${btn('Forever perks', 'perks')}${btn('How to use', 'help')}${btn('Install app', 'install')}${btn('Check for updates', 'check-updates', '', '', updateBusy)}</div><p class="muted">Forever ${esc(catalog.meta.build)} · data ${esc(catalog.meta.tag)} · v${esc(catalog.version)}</p><p><a href="./NOTICE.txt" target="_blank" rel="noopener">Data & artwork credits</a> · <a href="./LICENSE.txt" target="_blank" rel="noopener">License</a> · <a href="./THIRD-PARTY.txt" target="_blank" rel="noopener">Runtime credits</a></p></section></div>
  <footer><span>Forever ${esc(catalog.meta.build)} · v${esc(catalog.version)} · data ${esc(catalog.meta.tag)}</span><div data-full-view>${btn('Pet atlas', 'pets', '', 'quiet')}${btn('Perks', 'perks', '', 'quiet')}${btn('Library & sync', 'library', '', 'quiet')}</div><div class="update-controls">${btn('Check for updates', 'check-updates', '', 'quiet', updateBusy)}<span role="status">${esc(updateMessage)}</span></div><p class="project-notice"><span>Free, unofficial community project. Not affiliated with or endorsed by Blizzard Entertainment.</span><span>World of Warcraft artwork and text © Blizzard Entertainment and respective rights holders.</span><a href="./NOTICE.txt" target="_blank" rel="noopener">Copyright & ownership notice <span class="notice-link-hint">(opens in a new tab)</span></a></p></footer></main>
  <nav class="mobile-nav" aria-label="Calculator sections">${(state.simpleView
    ? [
        ['trees', '◇', 'Trees'],
        ['skills', '☷', 'Skills'],
      ]
    : [
        ['trees', '◇', 'Trees'],
        ['skills', '☷', 'Skills'],
        ['builds', '⑂', 'Builds'],
        ['more', '⋯', 'More'],
      ]
  )
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
  if (sheetTalent !== null) renderTalentSheet();
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
  window.scrollTo({ left: viewport.x, top: viewport.y, behavior: 'instant' });
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
  const training = engine.call('training').capture;
  const report = engine.call('trainingReport');
  const summary = $('#training-summary');
  summary.hidden = !report.enabled;
  summary.disabled = !report.ready;
  summary.textContent = report.caption || '';
  summary.title = report.note || '';
  summary.setAttribute('aria-label', [report.caption, report.note].filter(Boolean).join('. '));
  const caption = $('.skills-panel .muted');
  caption.textContent =
    currentSkillFilter() === 'trained' && training
      ? `Captured at level ${training.level}. Planned level does not change trained ranks.`
      : state.simpleView
        ? 'Check to keep colored talent highlights. Click a skill for unlock and upgrade levels.'
        : 'Check to keep talent highlights. Six colors repeat; shared talents show each color.';
  const entries = list(engine.call('skills', { query: skillQuery, filter: currentSkillFilter() }));
  $('#skill-list').innerHTML = entries.length
    ? entries
        .map(
          ({ skill: s, current, trained, shownTrained, comparison, progression }) =>
            `<div class="skill-row ${comparison?.needsTraining ? 'needs-training' : ''}"><input type="checkbox" data-skill-check="${esc(s.name)}" ${highlightStyle(s)} aria-label="Keep ${esc(s.name)} talent highlights" ${selected.has(skillKey(s)) ? 'checked' : ''}><button class="skill-details" data-skill="${esc(s.name)}" ${comparison ? `title="${esc(comparison.hint)}"` : ''}>${img(s.icon)}<span class="skill-name"><strong>${esc(s.name)}${shownTrained ? '<span class="trained-badge">Trained</span>' : ''}</strong><small>${progression ? `<svg class="unlock-icon" viewBox="0 0 16 18" role="img" aria-label="First unlock"><path d="M3 8V5a4 4 0 0 1 8-1M2 8h12v8H2z"/></svg>${esc(progression.summary)}` : comparison ? esc(comparison.label) : `${s.unlock ? `${esc(s.unlock.treeName)} talent · ` : `Lv. ${s.firstLevel} · `}${trained ? `Trained · ${esc(trained.label || 'ability')}` : current ? esc(current.label || 'available') : 'not yet available'}`}</small>${progression?.secondary ? `<small class="rank-progression">${progression.next ? `<svg class="unlock-icon" viewBox="0 0 16 18" role="img" aria-label="${progression.nextLocked ? 'Locked until level ' + progression.nextLevel : 'Next rank level reached'}"><path d="${progression.nextLocked ? 'M4 8V5a4 4 0 0 1 8 0v3' : 'M3 8V5a4 4 0 0 1 8-1'}M2 8h12v8H2z"/></svg>` : ''}${esc(progression.secondary)}</small>` : ''}</span>${comparison?.progress ? `<span class="skill-progress" aria-label="${esc(comparison.hint)}">${esc(comparison.progress)}</span>` : ''}</button></div>`
        )
        .join('')
    : currentSkillFilter() === 'needsTraining'
      ? `<p class="empty">${report.ready ? 'No matching skills need training at this level. Try another search or level.' : esc(report.note)}</p>`
      : skillFilter === 'trained'
        ? '<p class="empty">No captured trained skills. Import a character string captured by the addon.</p>'
        : '<p class="empty">No matches. Try another effect or category.</p>';
  const racials = list(engine.call('skills', { filter: 'racial' }));
  $('#racial-list').innerHTML = racials
    .map(
      ({ skill: s }) =>
        `<label class="racial"><input type="checkbox" data-skill-check="${esc(s.name)}" ${highlightStyle(s)} ${selected.has(skillKey(s)) ? 'checked' : ''} aria-label="Keep ${esc(s.name)} highlights">${btn(`${img(s.icon)}${esc(s.name)}`, 'racial', `data-name="${esc(s.name)}"`, 'quiet')}</label>`
    )
    .join('');
}
function paintHighlights() {
  const ids = highlight();
  for (const node of document.querySelectorAll('[data-talent]')) {
    const colors = Object.keys(ids[Number(node.dataset.talent)] || {})
      .map(Number)
      .sort((a, b) => a - b);
    node.classList.toggle('highlighted', colors.length > 0);
    node.style.setProperty(
      '--highlight-color',
      colors.length ? '#' + catalog.highlightPalette[colors[0]].hex : ''
    );
    let marks = node.querySelector('.highlight-colors');
    if (!marks) {
      marks = document.createElement('span');
      marks.className = 'highlight-colors';
      marks.setAttribute('aria-hidden', 'true');
      node.append(marks);
    }
    marks.innerHTML = colors
      .map((n) => `<i style="background:#${catalog.highlightPalette[n].hex}"></i>`)
      .join('');
  }
}
function renderOrder() {
  const index = Object.fromEntries(talents().map((t) => [t.id, t]));
  return (
    list(state.build.order)
      .map(
        (id, i) =>
          `<div class="order-step ${state.preview === i + 1 ? 'active' : ''}">${btn(`<span class="step-level">${i + 10}</span>${img(index[id].icon)}<span>${esc(index[id].name)}</span>`, 'preview', `data-count="${i + 1}" data-highlight-talent="${id}"`, 'step-main')}${btn('↑', 'reorder', `data-from="${i + 1}" data-to="${i}" aria-label="Move point ${i + 1} earlier"`, 'step-move', i === 0 || state.preview !== undefined)}${btn('↓', 'reorder', `data-from="${i + 1}" data-to="${i + 2}" aria-label="Move point ${i + 1} later"`, 'step-move', i === list(state.build.order).length - 1 || state.preview !== undefined)}</div>`
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
      return { ...n, x: depth[id] * 36, y: i * 104 };
    });
  const links = nodes
    .filter((n) => n.parent)
    .map((n) => {
      const parent = nodes.find((p) => p.id === n.parent);
      return `<path d="M${parent.x + 16} ${parent.y + 84} V${n.y + 42} H${n.x}"/>`;
    })
    .join('');
  $('#history-graph').innerHTML =
    `<div class="graph-heading"><h3>${esc(p.name)}</h3><small>${state.dirty ? 'Unsaved changes' : 'Saved'}</small></div><p class="graph-hint">Update saves into the active checkpoint. Save as new checkpoint creates a child. Loading another node leaves edits unsaved; Undo brings them back.</p><div class="graph-scroll" tabindex="0" role="region" aria-label="Checkpoint tree"><div class="graph" style="height:${nodes.length * 104}px;min-width:${Math.max(...nodes.map((n) => n.x)) + 268}px"><svg aria-hidden="true" width="100%" height="100%">${links}</svg>${nodes.map((n) => `<div class="graph-node ${state.activeNode === n.id ? 'active' : ''}" style="left:${n.x}px;top:${n.y}px">${btn(`${state.activeNode === n.id ? '<span class="active-node-badge">ACTIVE</span>' : ''}<strong>${esc(n.title)}</strong><small>Lv. ${n.build.level} · ${list(n.build.order).length} ${list(n.build.order).length === 1 ? 'point' : 'points'}${n.build.legacyTag ? ' · Needs repair' : ''}</small>`, 'load', `data-profile="${p.id}" data-node="${n.id}" title="${esc(n.title)}" ${state.activeNode === n.id ? 'aria-current="true"' : ''}`, 'node-main')}${btn('×', 'delete-node', `data-profile="${p.id}" data-node="${n.id}" aria-label="Delete ${esc(n.title)} and descendants"`, 'node-delete')}</div>`).join('')}</div></div>`;
  const scroll = $('.graph-scroll');
  if (!scroll.clientHeight) return;
  const activeID = state.activeNode;
  const active = nodes.find((n) => n.id === activeID);
  if (
    graphView.profileID !== p.id ||
    graphView.activeID !== activeID ||
    graphView.width !== scroll.clientWidth
  ) {
    graphView = {
      profileID: p.id,
      activeID,
      left: Math.max(
        0,
        active.x + $('.graph-node.active').offsetWidth / 2 - scroll.clientWidth / 2 + 8
      ),
      top: Math.max(0, active.y - scroll.clientHeight / 2 + 42),
    };
  }
  graphView.width = scroll.clientWidth;
  scroll.scrollLeft = graphView.left;
  scroll.scrollTop = graphView.top;
}
const dialogStack = [];
function openDialog(title, html, wide = false, onReturn = null) {
  if (modal.open && modal.dataset.dialogTitle !== title) {
    const previous = dialogStack.findIndex((entry) => entry.title === title);
    if (previous >= 0) dialogStack.splice(previous);
    else {
      const fragment = document.createDocumentFragment();
      const scrollTop = modal.scrollTop;
      while (modal.firstChild) fragment.append(modal.firstChild);
      dialogStack.push({
        title: modal.dataset.dialogTitle,
        fragment,
        className: modal.className,
        scrollTop,
        onReturn: modal.onReturn,
      });
      if (dialogStack.length > 16) dialogStack.shift();
    }
  }
  modal.dataset.dialogTitle = title;
  modal.onReturn = onReturn;
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
  modal.innerHTML = `<div class="modal-head"><h2 id="dialog-title">${esc(title)}</h2>${btn('×', 'close', `aria-label="Close dialog" title="${dialogStack.length ? 'Back to previous screen' : 'Close'}"`, 'close')}</div><div class="modal-body">${html}</div>`;
  modal.className = wide ? 'wide-modal' : '';
  modal.setAttribute('aria-labelledby', 'dialog-title');
  if (!modal.open) modal.showModal();
  modal.scrollTop = 0;
  modal.querySelector('[data-action="close"]').focus({ preventScroll: true });
}
function closeDialog(dismiss = false) {
  const linkHash = $('#import-code')?.dataset.linkHash;
  if (linkHash && location.hash === linkHash)
    history.replaceState(history.state, '', location.pathname + location.search);
  const previous = !dismiss && dialogStack.pop();
  if (previous) {
    modal.replaceChildren(previous.fragment);
    modal.className = previous.className;
    modal.dataset.dialogTitle = previous.title;
    modal.onReturn = previous.onReturn;
    previous.onReturn?.();
    modal.scrollTop = previous.scrollTop;
    modal.querySelector('[data-action="close"]').focus({ preventScroll: true });
    return;
  }
  dialogStack.length = 0;
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
  if (matchMedia('(max-width: 1050px), (pointer: coarse)').matches) {
    const sameTalent = sheetTalent === Number(id) && talentSheet.open;
    sheetTalent = Number(id);
    renderTalentSheet();
    if (!talentSheet.open) talentSheet.show();
    document.body.classList.add('talent-sheet-open');
    if (!sameTalent) {
      talentSheet.querySelector('details').open = false;
      talentSheet.querySelector('.talent-sheet-body').scrollTop = 0;
      talentSheet.querySelector('[data-action="close-talent"]').focus({ preventScroll: true });
      requestAnimationFrame(() => positionTalentSheet(id));
    }
    return;
  }
  closeTalentSheet(false);
  const available = engine.call('talents')[t.id].available;
  const related = list(engine.call('talentSkills', { id: t.id }));
  openDialog(
    t.name,
    `${description(t)}<div class="allocation-actions">${btn('− Remove', 'talent-remove', `data-id="${id}"`, '', !(state.counts[id] > 0) || state.preview !== undefined)}${btn('+ Add point', 'talent-add', `data-id="${id}"`, 'primary', !available || state.preview !== undefined)}${btn('Fill ranks', 'talent-fill', `data-id="${id}"`, '', !available || state.preview !== undefined)}${btn('Clear ranks', 'talent-clear', `data-id="${id}"`, '', !(state.counts[id] > 0) || state.preview !== undefined)}</div><details><summary>Every rank</summary>${list(
      t.ranks
    )
      .map((r, i) => `<p><b>Rank ${i + 1}</b><br>${esc(r.text)}</p>`)
      .join(
        ''
      )}</details>${!state.simpleView && related.length ? `<h3>Related skills</h3><div class="chips">${related.map((n) => btn(esc(n), 'related-skill', `data-name="${esc(n)}"`)).join('')}</div>` : ''}`
  );
}
function positionTalentSheet(id) {
  if (!talentSheet.open || sheetTalent !== Number(id)) return;
  const node = $(`[data-talent="${id}"]`);
  if (!node) return;
  const rect = node.getBoundingClientRect();
  // Ignore the opening animation when measuring the space above the sheet.
  const top = document.documentElement.clientHeight - talentSheet.offsetHeight;
  if (rect.bottom > top - 16 || rect.top < 16)
    window.scrollBy({
      top: rect.top - Math.max(16, (top - rect.height) / 2),
      behavior: 'instant',
    });
}
function renderTalentSheet() {
  const t = talent(sheetTalent);
  if (!t) {
    closeTalentSheet(false);
    return;
  }
  const rank = state.counts[t.id] || 0;
  const access = engine.call('talents')[t.id];
  const related = !state.simpleView && list(engine.call('talentSkills', { id: t.id }));
  if (talentSheet.dataset.talent !== String(t.id)) {
    talentSheet.dataset.talent = String(t.id);
    talentSheet.innerHTML = `<header class="talent-sheet-head">${img(t.icon)}<div><h2 id="talent-sheet-title">${esc(t.name)}</h2><span class="muted" data-sheet-context>${esc(list(cls().trees).find((tree) => list(tree.talents).some((n) => n.id === t.id))?.name)} · Level ${state.viewLevel} · ${Math.max(0, state.budget - order().length)} points left</span><span class="sheet-checkpoint" data-sheet-checkpoint></span></div>${btn('×', 'close-talent', 'aria-label="Close talent details"', 'close')}</header><div class="talent-sheet-body"><div class="talent-sheet-description">${description(t)}</div><details><summary>Every rank & related skills</summary>${list(
      t.ranks
    )
      .map((r, i) => `<p><b>Rank ${i + 1}</b><br>${esc(r.text)}</p>`)
      .join(
        ''
      )}${related?.length ? `<h3>Related skills</h3><div class="chips">${related.map((n) => btn(esc(n), 'related-skill', `data-name="${esc(n)}"`)).join('')}</div>` : ''}<div class="allocation-actions">${btn('Fill ranks', 'talent-fill', `data-id="${t.id}"`, '', !access.available || state.preview !== undefined)}${btn('Clear ranks', 'talent-clear', `data-id="${t.id}"`, '', !rank || state.preview !== undefined)}</div></details></div><footer class="talent-sheet-actions">${btn('−', 'talent-remove', `data-id="${t.id}" aria-label="Remove one point from ${esc(t.name)}"`, '', !rank || state.preview !== undefined)}<span aria-live="polite" data-sheet-rank><b>${rank}</b> / ${t.max}</span>${btn('+', 'talent-add', `data-id="${t.id}" aria-label="Add one point to ${esc(t.name)}"`, 'primary', !access.available || state.preview !== undefined)}</footer>`;
  } else {
    const body = talentSheet.querySelector('.talent-sheet-body');
    const scrollTop = body.scrollTop;
    talentSheet.querySelector('[data-sheet-context]').textContent =
      `${list(cls().trees).find((tree) => list(tree.talents).some((n) => n.id === t.id))?.name} · Level ${state.viewLevel} · ${Math.max(0, state.budget - order().length)} points left`;
    talentSheet.querySelector('.talent-sheet-description').innerHTML = description(t);
    talentSheet.querySelector('[data-sheet-rank]').innerHTML = `<b>${rank}</b> / ${t.max}`;
    for (const action of ['talent-add', 'talent-fill'])
      talentSheet.querySelector(`[data-action="${action}"]`).disabled =
        !access.available || state.preview !== undefined;
    for (const action of ['talent-remove', 'talent-clear'])
      talentSheet.querySelector(`[data-action="${action}"]`).disabled =
        !rank || state.preview !== undefined;
    body.scrollTop = scrollTop;
  }
  const checkpointLabel = talentSheet.querySelector('[data-sheet-checkpoint]');
  const active = state.profiles[state.activeProfile]?.nodes[state.activeNode];
  checkpointLabel.hidden = state.simpleView;
  checkpointLabel.textContent = active
    ? `Active: ${active.title}${state.dirty ? ' · Unsaved changes' : ''}`
    : 'No saved checkpoint';
  checkpointLabel.title = checkpointLabel.textContent;
  for (const node of document.querySelectorAll('[data-talent]'))
    node.classList.toggle('inspecting', Number(node.dataset.talent) === sheetTalent);
}
function closeTalentSheet(restoreFocus = true) {
  const id = sheetTalent;
  sheetTalent = null;
  talentSheet.close();
  document.body.classList.remove('talent-sheet-open');
  document
    .querySelectorAll('.talent.inspecting')
    .forEach((node) => node.classList.remove('inspecting'));
  if (restoreFocus && id !== null) $(`[data-talent="${id}"]`)?.focus({ preventScroll: true });
}
function showSkill(name) {
  try {
    const s = engine.call('skill', { name });
    const comparison = engine.call('trainingReport').skills?.[name];
    const trainingNote = comparison
      ? `<p class="callout training-note">${esc(comparison.label)} · ${esc(comparison.hint)}</p>`
      : '';
    if (state.simpleView) {
      const progression = engine.call('skillLevels', { name });
      const levels = list(progression.ranks);
      openDialog(
        `${s.name} · Skill levels`,
        `<div class="detail-title">${img(s.icon)}<h3>${esc(s.name)}</h3></div>${s.unlock ? `<p class="muted">Unlocked by ${esc(s.unlock.name)} in ${esc(s.unlock.treeName)}. Earliest talent level ${progression.unlockLevel}.</p>` : `<p class="muted">First learned at level ${levels[0]?.level ?? s.firstLevel}.</p>`}${trainingNote}<div class="skill-levels">${levels.length ? levels.map((r) => `<div class="skill-level"><b>${esc(r.label)}</b><span>Level ${r.level}${r.toLevel ? `–${r.toLevel}` : ''}${r.talentGranted ? ' · talent unlock' : ''}${r.talentRank ? ` · talent rank ${r.talentRank}` : ''}</span></div>`).join('') : '<p class="empty">No trainable rank levels recorded.</p>'}</div>${s.unlock ? '<p class="muted">Talent skills also require their talent to be learned.</p>' : ''}`
      );
      return;
    }
    hovered = s;
    paintHighlights();
    const ranks = list(s.ranks);
    const trained = engine.call('training', { name }).rank;
    const rel = list(s.related);
    openDialog(
      s.name,
      `<div class="detail-title">${img(s.icon)}<h3>${esc(s.name)}</h3><span class="badge">${esc(s.kind)}</span></div>${s.unlock ? `<p class="callout">Unlocked by <b>${esc(s.unlock.name)}</b> in ${esc(s.unlock.treeName)}, row ${s.unlock.row + 1} (${s.unlock.gate} points in tree first).</p>` : `<p class="muted">First learned at level ${s.firstLevel}. All captured ranks appear below.</p>`}${trainingNote}<p class="muted">Base ability values from the client snapshot; talents, haste and temporary effects may change them.</p><label class="pin"><input type="checkbox" data-skill-check="${esc(s.name)}" ${highlightStyle(s)} ${selected.has(skillKey(s)) ? 'checked' : ''}>Keep talent highlights</label><div class="skill-ranks">${ranks.map((r, i) => `<article class="rank-card ${r.live ? '' : 'archived'}"><div><b>${esc(r.label || 'Ability')}</b><span>Lv. ${r.level}${r.talentGranted ? ' · talent unlock' : ''}${r.talentRank ? ` · talent rank ${r.talentRank}` : ''}${r.fromLevel ? ` · Lv. ${r.fromLevel}–${r.toLevel || 60}` : ''}${r.live ? '' : ' · archived'}${trained?.spellID === r.spellID ? ' · captured trained rank' : ''}</span></div><p class="ability-details">${esc(r.abilityDetails || 'Base cast time and cooldown not recorded.')}</p><p>${esc(r.text || 'No description recorded in the captured snapshot.')}</p>${btn('Experimental simulator', 'simulate', `data-simulation-feature data-name="${esc(s.name)}" data-rank="${i + 1}"`, 'quiet')}</article>`).join('')}</div><h3>Talent interactions <span class="muted">${rel.length}</span></h3>${rel.length ? rel.map((r) => `<div class="relation">${btn(esc(talent(r.id)?.name || r.id), 'locate', `data-id="${r.id}"`)}<p>${esc(r.reason)}</p></div>`).join('') : '<p class="muted">No specific talent interaction is described in the captured data.</p>'}`
    );
  } catch (e) {
    toast(e.message, true);
  }
}
function showImport(code = '', buildLink = false) {
  const profileLink = buildLink === 'profile';
  openDialog(
    profileLink
      ? 'Open build + checkpoints'
      : buildLink
        ? 'Open shared build'
        : 'Import from addon or another device',
    `<p class="muted">${buildLink ? 'Review this build before loading. Your saved builds stay here, and Undo can restore your draft.' : 'Build/profile link or <b>FT1 / FP1</b> · character <b>FC1</b> · stats & gear <b>FS2</b> (FS1 supported) · full library <b>FL1</b>. Your draft stays here until you load.'}</p><label class="field-label" for="import-code">${buildLink ? 'Shared build link' : 'Paste a complete build link or sharing string'}</label><textarea id="import-code" rows="${buildLink ? 3 : 5}" maxlength="3145728" spellcheck="false" autocapitalize="off" autocomplete="off" ${buildLink ? `data-${profileLink ? 'profile' : 'build'}-only="true" data-link-hash="${esc(location.hash)}"` : ''}>${esc(code)}</textarea><div id="import-preview" class="callout">Paste a link or string to preview it.</div><div id="profile-preview" class="import-checkpoints" hidden></div><label class="pin" id="import-drafts-label" hidden><input id="import-drafts" type="checkbox">Also replace class drafts when merging the library</label><p class="muted" id="import-note"></p><div class="dialog-actions">${btn(buildLink ? 'Load build' : 'Load snapshot', 'import-load', '', 'primary', true)}${btn('Cancel', 'close')}</div>`
  );
  if (code) previewImport();
  $('#import-code').focus({ preventScroll: true });
}
function previewImport() {
  const input = $('#import-code').value;
  const load = $('[data-action="import-load"]');
  try {
    const snap = engine.call('decode', {
      code: input,
      buildOnly: $('#import-code').dataset.buildOnly === 'true',
      profileOnly: $('#import-code').dataset.profileOnly === 'true',
    });
    load.disabled = false;
    $('#import-drafts-label').hidden = snap.kind !== 'library';
    load.textContent =
      snap.kind === 'profile'
        ? 'Open build + checkpoints'
        : snap.kind === 'library'
          ? 'Merge library'
          : snap.kind === 'build'
            ? 'Load build'
            : 'Load snapshot';
    $('#import-preview').textContent =
      snap.kind === 'profile'
        ? `${snap.profile.name} · ${catalog.classes[snap.build.classID].name} · ${snap.nodes} checkpoints`
        : snap.kind === 'library'
          ? `${snap.profiles} profiles · ${snap.nodes} checkpoints · ${snap.drafts} class drafts`
          : `${snap.build ? snap.build.name + ' · ' : ''}${catalog.classes[(snap.build || snap.stats).classID].name} · ${catalog.races[(snap.build || snap.stats).raceID].name} · level ${(snap.build || snap.stats).level} · ${snap.kind}${snap.build ? ` · ${list(snap.build.order).length} points` : ''}`;
    $('#import-note').textContent =
      snap.kind === 'profile'
        ? 'Opens the complete checkpoint tree with titles, branches and exact talent orders. Your other builds and character stats stay here. Identical profiles are reused.'
        : snap.kind === 'library'
          ? 'Profiles merge without replacing existing profiles; exact duplicates are skipped. Character workspaces and simulation settings also sync. Checked above: incoming class drafts replace drafts for those classes. Export your library first for a backup.'
          : snap.kind === 'stats'
            ? 'Loads simulation stats only. Your talents, race and level stay as they are.'
            : snap.kind === 'build'
              ? 'Loads class, race, level, talents and exact point order into a draft. Saved profiles and character stats stay here. Save it as a new build to keep a named copy.'
              : 'Loads the shared class, race, level and talent order. Character snapshots also load the central stat/equipment workspace. Undo restores talents; character stats stay separate.';
    $('#profile-preview').hidden = snap.kind !== 'profile';
    if (snap.kind === 'profile') {
      const depths = {};
      $('#profile-preview').innerHTML = list(snap.profile.order)
        .map((id) => {
          const n = snap.profile.nodes[id];
          depths[id] = n.parent ? depths[n.parent] + 1 : 0;
          return `<div style="padding-left:${Math.min(depths[id], 8) * 12}px"><strong>${esc(n.title)}</strong><small>Lv. ${n.build.level} · ${list(n.build.order).length} points${n.build.legacyTag ? ' · needs repair' : ''}${id === snap.selected ? ' · opens here' : ''}</small></div>`;
        })
        .join('');
    }
  } catch (e) {
    load.disabled = true;
    $('#import-drafts-label').hidden = true;
    $('#profile-preview').hidden = true;
    $('#import-preview').textContent = input ? e.message : 'Paste a string to preview it.';
    $('#import-note').textContent = '';
  }
}
function openBuildLink() {
  if (location.hash.startsWith('#build=')) showImport(catalog.buildURL + location.hash, true);
  else if (location.hash.startsWith('#profile='))
    showImport(catalog.buildURL + location.hash, 'profile');
}
function showShare(kind = 'link', context = {}) {
  openDialog(
    'Copy & share',
    `<p class="muted">Send a build link for a friend to open in their browser, or copy a sharing string for the addon and PWA. Friends need the same data version for talent builds.</p><label class="field-label" for="share-kind">What to copy</label><select id="share-kind">${[
      ['link', 'Web link to this build'],
      ['profileLink', 'Build + checkpoints link'],
      ['profile', 'Build + checkpoints string'],
      ['build', 'Talent build + ordered points'],
      ...(state.build.recovery ? [['original', 'Original build before migration']] : []),
      ['character', 'Character: level + talents + stats + gear'],
      ['stats', 'Character stats + gear (or temporary skill inputs)'],
      ['library', 'Whole library: builds + branches + drafts'],
    ]
      .map(
        ([id, title]) =>
          `<option value="${id}" ${id === kind ? 'selected' : ''} ${(id === 'profileLink' || id === 'profile') && !(context.profileID || state.activeProfile) ? 'disabled' : ''}>${title}</option>`
      )
      .join(
        ''
      )}</select><label class="field-label" id="share-label" for="share-code">Sharing string</label><textarea id="share-code" rows="5" readonly spellcheck="false"></textarea><p class="muted" id="share-note"></p><div class="dialog-actions">${btn('Copy build link', 'copy-code', '', 'primary')}${btn('Save to file', 'download-code')}${btn('Import a link or string', 'import')}</div><p class="muted">In-game clickable whispers need the WoW addon. You can also paste web links into Import in the addon.</p>`
  );
  modal.shareContext = context;
  refreshShare();
}
function refreshShare() {
  try {
    const kind = $('#share-kind').value;
    const code = engine.call('export', { kind, ...modal.shareContext });
    const isLink = kind === 'link' || kind === 'profileLink';
    $('[data-action="copy-code"]').disabled = false;
    $('[data-action="download-code"]').disabled = false;
    $('#share-code').value = code;
    $('#share-code').rows = isLink ? 3 : 5;
    $('#share-label').textContent =
      kind === 'profileLink'
        ? 'Build + checkpoints link'
        : isLink
          ? 'Build link'
          : 'Sharing string';
    $('[data-action="copy-code"]').textContent = isLink ? 'Copy build link' : 'Copy string';
    $('#share-note').textContent =
      kind === 'profileLink' || kind === 'profile'
        ? 'Includes this saved build and all its saved checkpoint branches. Unsaved edits are excluded; use Update checkpoint or New checkpoint first to share them. Your friend can preview the tree before opening it. Other profiles, character stats and equipment are not included. Very large trees can use a profile string or file.'
        : kind === 'link'
          ? 'Includes class, race, displayed level, talents and exact point order. Your friend can review before loading; no account needed. Character stats, gear and your library are shared separately.'
          : kind === 'original'
            ? 'Recoverable original allocation and exact order from before the rule change. Importing it shows the repair notice again; it never replaces your saved branches automatically.'
            : kind === 'library'
              ? `Full library export · ${code.length.toLocaleString()} characters. Includes checkpoints, all class drafts, undo/redo and simulation stats. Native window settings and received whispers stay on their own device.`
              : kind === 'stats'
                ? 'Character exports include the central workspace and equipment. Temporary skill inputs can be pasted inside Simulator without changing Character. Live captures retain reported power/crit by school.'
                : 'The exported level is the displayed level. Preview mode exports only the displayed talent prefix.';
  } catch (e) {
    $('#share-code').value = '';
    $('[data-action="copy-code"]').disabled = true;
    $('[data-action="download-code"]').disabled = true;
    $('#share-note').textContent = e.message;
    toast(e.message, true);
  }
}
async function copyCode() {
  const field = $('#share-code');
  try {
    await navigator.clipboard.writeText(field.value);
    toast(
      ['link', 'profileLink'].includes($('#share-kind').value)
        ? 'Build link copied. Send it to a friend to open in the web app.'
        : 'Copied. Paste into the addon or another device.'
    );
  } catch {
    field.focus({ preventScroll: true });
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
    `<p class="muted">Saved builds, editable checkpoints and alternate branches. Your class drafts autosave separately.</p><div class="dialog-actions">${btn('New build', 'save', '', 'primary')}${btn('Export whole library', 'export-library')}${btn('Import / merge library', 'import')}${btn('Open sharing file', 'open-file')}</div><input id="sharing-file" type="file" accept=".txt,.ftc,text/plain" hidden><div class="library-list">${profiles.length ? profiles.map((p) => `<article class="library-card"><div><h3>${esc(p.name)}</h3><p class="muted">${esc(catalog.classes[p.nodes[list(p.order)[0]].build.classID].name)} · ${list(p.order).length} checkpoints</p></div><div>${btn('Open', 'load', `data-profile="${p.id}" data-node="${list(p.order).at(-1)}"`, 'primary')}${btn('Share checkpoints', 'share-profile', `data-profile="${p.id}"`)}${btn('Rename', 'rename', `data-profile="${p.id}"`)}${btn('Delete', 'delete-profile', `data-profile="${p.id}"`, 'danger')}</div></article>`).join('') : '<p class="empty">No saved profiles yet. Choose Save build to start one.</p>'}</div><p class="callout">To sync everything: Export whole library → copy the string or save a file → open Character in the addon or Import in this app → merge. Profiles with identical contents are skipped. Export before replacing class drafts.</p>`,
    true,
    showLibrary
  );
}
function showTalentPaste() {
  openDialog(
    'Paste talents',
    `<p>Replaces only talents and point order. Keeps the active checkpoint, race, level and character stats.</p><label class="field-label" for="talents-code">Talents-only string</label><textarea id="talents-code" rows="3" maxlength="512" spellcheck="false" placeholder="Paste the string from Copy talents…"></textarea><p id="talents-preview" class="muted" role="status">Paste to preview before applying.</p><div class="dialog-actions">${btn('Paste talents', 'apply-talents', '', 'primary', true)}${btn('Cancel', 'close')}</div>`
  );
  $('#talents-code').focus({ preventScroll: true });
}
function previewTalentsPaste() {
  try {
    const build = engine.call('talentsPreview', { code: $('#talents-code').value });
    $('#talents-preview').textContent =
      `${list(build.order).length} talent points · ${catalog.classes[build.classID].name}. Choose Update checkpoint to save here, or Save as new checkpoint.`;
    $('[data-action="apply-talents"]').disabled = false;
  } catch (e) {
    $('#talents-preview').textContent = e.message;
    $('[data-action="apply-talents"]').disabled = true;
  }
}
async function copyTalents() {
  const code = engine.call('copyTalents');
  try {
    await navigator.clipboard.writeText(code);
    toast('Talents copied. Load the destination checkpoint, then choose Paste talents.');
  } catch {
    openDialog(
      'Copy talents',
      `<p>Class and ordered talent points only. Select the string and copy it, then load your destination and use Paste talents.</p><label class="field-label" for="talents-copy">Talents-only string</label><textarea id="talents-copy" readonly rows="3">${esc(code)}</textarea>`
    );
    $('#talents-copy').focus({ preventScroll: true });
    $('#talents-copy').select();
  }
}
function showSettings() {
  openDialog(
    'Settings',
    `<label class="pin"><input id="show-simulation" type="checkbox" ${state.simulationEnabled ? 'checked' : ''}>Show experimental simulator</label><p class="muted">One-use estimates are experimental and have not been validated in live gameplay. Turn this off to hide Character and simulator buttons; saved stats and equipment stay on this device.</p><div class="dialog-actions">${btn('Done', 'close', '', 'primary')}${btn('Guide', 'help')}</div>`
  );
}
function showSave(checkpoint = false) {
  openDialog(
    checkpoint ? 'Save a checkpoint' : 'Save a named build',
    `<p class="muted">${checkpoint ? 'This checkpoint branches from the selected node. Older checkpoints stay intact.' : 'Keeps this allocation and its exact leveling order. Add checkpoints as you explore.'}</p><label class="field-label" for="save-title">${checkpoint ? 'Checkpoint title' : 'Build name'}</label><input id="save-title" maxlength="48" value="${checkpoint ? '' : esc(state.build.name === 'Untitled build' ? '' : state.build.name)}" placeholder="${checkpoint ? 'Level 30 · alternate route' : 'My leveling build'}"><div class="dialog-actions">${btn('Save', checkpoint ? 'confirm-checkpoint' : 'confirm-save', '', 'primary')}${btn('Cancel', 'close')}</div>`
  );
  $('#save-title').focus({ preventScroll: true });
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
  if (state.simpleView) {
    openDialog(
      'Simple view',
      '<p>Pick a class and fill its talent trees. Auto follows spent points; Undo / Redo restore edits. On phones, tap a talent, then choose Add or Remove.</p><p>Check skill boxes to keep their colored talent highlights; Clear highlights unchecks them all. Click a skill to see its unlock level and rank upgrade levels. The availability filter follows the level and talents in your current build.</p><p>Your class drafts still autosave on this device. Turn off <b>Simple view</b> above the class picker to restore race, character, sharing and checkpoint tools. Your saved builds and character settings are kept.</p>'
    );
    return;
  }
  openDialog(
    'A quick guide',
    `<div class="guide-grid"><article><h3>Plan the journey</h3><p>On desktop, click a talent to add a point; right-click removes one. Alt-click opens the full talent details and affected skills. Shift fills or clears its ranks. On phones, tap a talent to open the bottom panel, then use + / −. The tree stays scrollable and interactive; tap another talent to inspect it without closing. Keyboard users can focus a talent and press Enter to inspect it.</p><p>Each row needs five more points in earlier rows of the same tree: 5 for row 2, 10 for row 3, and so on. The points can be spread across those earlier rows; individual rows do not each need five. Prerequisites, maximum ranks and level budgets come from the same engine as the addon. Auto raises and lowers your level as you spend or remove points. If a removal needs a different legal leveling order, the calculator adjusts only the necessary steps and tells you. Undo restores the original order.</p></article><article><h3>Find the interactions</h3><p>Search skills and talents by name or description. Hover a skill for temporary highlights, or check boxes to keep several highlights. Clear highlights unchecks every selection. Open a skill for all ranks, unlock levels and talent links. Each class-skill row shows its first unlock level and the displayed rank’s own level. Trained marks imported spellbook ranks. A second line shows the next rank with a lock until its required level; the line disappears at maximum rank. Talent requirements still apply. This works with comparison off.</p><p>Enable Compare imported character to check your last imported spellbook against the displayed level and talents. Gold rows need a new skill or higher rank; Needs training filters them. ↑3 means three more levels until the next rank or first unlock, and ↑0 means that level is reached. Talent requirements still apply. Re-import after learning skills; the comparison is a snapshot.</p><p>Character keeps a central stat and equipment plan per class. Simulator inherits it, shows only applicable inputs, and keeps experiments temporary. Expected totals average crits and failed casts. Open the calculation and accuracy details for formulas, sources and missing mechanics.</p></article><article><h3>Checkpoint and branch</h3><p>Open <b>Checkpoints & order</b> on desktop or <b>Builds</b> on a phone for the full checkpoint workspace. The tree scrolls vertically and horizontally, with the selected node brought into view and long titles wrapped.</p><p>Save a build, then save titled checkpoints. Load a checkpoint, edit its talents or level, then choose <b>Update checkpoint</b> to replace that snapshot while keeping its title and all branches. <b>Save as new checkpoint</b> saves a separate child. The active checkpoint stays highlighted while you edit; Unsaved changes means those edits have not been saved into it. Loading another checkpoint never creates a node. Undo returns to edits you left behind. Use Copy talents beside the trees, load the destination checkpoint, then Paste talents to move an allocation without changing the destination race, level or stats. Save it with either checkpoint button. Deleting a node deletes its descendants; your current allocation stays here. Undo / Redo keep 100 edits per class.</p><p>Hover or keyboard-focus a talent-order step to highlight its talent. Click or tap it to preview that level. Full build exits preview. Branch here turns that prefix into a draft you can checkpoint.</p></article><article><h3>Share & sync</h3><p>Share → Copy build link sends a browser link with the displayed class, race, level, talents and exact point order. Friends review it before loading; no account is needed. Addon Share → Web link makes the same link, and either interface accepts it through Import.</p><p>For the full branch tree, choose Share → Build + checkpoints link, or Share checkpoints in Library. It includes every saved node; unsaved drafts are excluded. Update or create a checkpoint before sharing current edits; other builds and character stats stay private. FP1 strings provide the same profile transfer, with files available for large trees.</p><p>FT1 shares talents and their order. FC1 adds level, character stats and equipment. FS2 shares character stats and gear, or temporary skill inputs; FS1 is still supported. FL1 transfers your full build library, branches and class drafts. In the addon, open Import or Character → Import my talents & skills to capture the logged-in character. The Trained filter shows captured spellbook ranks rather than the highest rank available to the plan.</p><p>A browser cannot read a running WoW client. Copy the capture in the addon and paste it here. Apply or cancel pending changes in the game’s Talents window before capturing. If client data is still loading, open Talents and Spellbook and retry; a failed import keeps the current build. Original live spending order is unavailable; live imports derive a legal order.</p></article><article><h3>Offline & install</h3><p>After the offline status says Ready, the calculator works without a connection. Install from the app button or your browser menu. iPhone/iPad: Safari → Share → Add to Home Screen. Windows/Linux/Android: an install-capable browser can create an app shortcut.</p><p>Browser saves stay on this device. Export your library before clearing website data or switching browsers. The footer shows your installed version. <b>Check for updates</b> is in the footer and the phone’s More section. It reports when that version is current or the new files are downloading. <b>Update now</b> appears once the complete release is cached and keeps your local library. Connect to the internet to check; no prompt is needed if you already have the current release.</p></article><article><h3>Experimental tools</h3><p>Settings → <b>Show experimental simulator</b> hides or restores Character and simulator buttons. Estimates have not been validated in live gameplay. Turning the setting off keeps your saved stats, gear and build library. This preference stays on this device; library sync does not change it.</p><p>In the addon, <b>Compact view</b> uses a small movable window with Trees, Skills and Builds tabs. It works alongside Simple view, retains the authentic grid and keeps separate window positions for each size.</p></article><article><h3>Data notes</h3><p>Captured Forever ${esc(catalog.meta.build)} / ${esc(catalog.meta.buildNumber)}, ${esc(catalog.meta.generatedAt.slice(0, 10))}. Missing descriptions are marked. Simulator uses a separately dated client-effect snapshot and reviewed developer corrections. Unknown scaling is marked as unverified and contributes no power until you supply a coefficient. Reference base stats are estimates; native live captures retain reported totals.</p><p>Class talents, legacy perks and pet reference tables have separate systems. Perks are a read-only atlas, not part of the 51 talent points.</p></article></div>`,
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
    `<p class="muted">Rank levels and tameable beasts from the captured dataset.</p>${list(
      catalog.pets.notes
    )
      .map(
        (note) => `<p class="notice"><strong>${esc(note.title)}</strong><br>${esc(note.text)}</p>`
      )
      .join(
        ''
      )}<div class="pet-filters"><input id="pet-search" type="search" value="${esc(pet.query)}" placeholder="Search pet skills or beasts…" aria-label="Search pets"><select id="pet-family" aria-label="Pet family"><option value="">All families</option>${list(
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
function changeContext(dismissDialogs = false) {
  closeTalentSheet(false);
  if (dismissDialogs && modal.open) closeDialog(true);
  selected.clear();
  selectionColors.clear();
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
      if (event.altKey) showTalent(id);
      else if (event.ctrlKey || event.metaKey) {
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
      case 'close-talent':
        closeTalentSheet();
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
        closeTalentSheet(false);
        treeTab = Number(node.dataset.index);
        render();
        break;
      case 'panel':
        closeTalentSheet(false);
        panel = node.dataset.panel;
        render();
        if (matchMedia('(min-width: 1051px)').matches && !state.simpleView)
          $('.workspace-nav').scrollIntoView({ block: 'start', behavior: 'instant' });
        else if (panel === 'builds')
          $('.builds-panel').scrollIntoView({ block: 'start', behavior: 'instant' });
        else window.scrollTo({ top: 0, behavior: 'instant' });
        break;
      case 'clear-highlights':
        selected.clear();
        selectionColors.clear();
        hovered = null;
        renderSkills();
        paintHighlights();
        break;
      case 'needs-training':
        skillFilter = 'needsTraining';
        $('#skill-filter').value = skillFilter;
        renderSkills();
        break;
      case 'racial':
      case 'related-skill':
        showSkill(node.dataset.name);
        break;
      case 'locate': {
        const t = talent(id);
        treeTab = list(cls().trees).findIndex((tr) => list(tr.talents).some((n) => n.id === id));
        panel = 'trees';
        closeDialog(true);
        render();
        $(`[data-talent="${id}"]`).focus();
        showTalent(id);
        break;
      }
      case 'talent-add':
      case 'talent-fill':
        if (act('add', { id, fill: a === 'talent-fill' }) !== null && !talentSheet.open)
          showTalent(id);
        break;
      case 'talent-remove':
      case 'talent-clear':
        if (act('remove', { id, all: a === 'talent-clear' }) !== null && !talentSheet.open)
          showTalent(id);
        break;
      case 'settings':
        showSettings();
        break;
      case 'copy-talents':
        await copyTalents();
        break;
      case 'paste-talents':
        showTalentPaste();
        break;
      case 'apply-talents':
        if (act('pasteTalents', { code: $('#talents-code').value }) !== null) closeDialog();
        break;
      case 'save':
        showSave();
        break;
      case 'update-checkpoint':
        act('updateCheckpoint');
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
          closeDialog(true);
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
            buildOnly: $('#import-code').dataset.buildOnly === 'true',
            profileOnly: $('#import-code').dataset.profileOnly === 'true',
            includeDrafts: $('#import-drafts').checked,
          }) !== null
        ) {
          changeContext();
          closeDialog();
          render();
          toast(state.message || 'Imported.');
        }
        break;
      case 'share-original':
        showShare('original');
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
      case 'share-profile':
        showShare('profileLink', { profileID });
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
        closeDialog(true);
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
      case 'check-updates':
        if (updateMonitor) await updateMonitor.check();
        else
          toast(
            navigator.onLine
              ? 'Update checking is unavailable in this preview or browser.'
              : 'You are offline. Connect to check for updates.',
            true
          );
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
  if (t.id === 'talents-code') previewTalentsPaste();
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
    for (const [key, s] of selected)
      if (s.kind === 'racial') {
        selected.delete(key);
        selectionColors.delete(key);
      }
    act('race', { raceID: Number(t.value) });
  }
  if (t.id === 'show-simulation') act('simulationEnabled', { enabled: t.checked });
  if (t.id === 'simple-view') {
    if (t.checked && !['trees', 'skills'].includes(panel)) panel = 'trees';
    hovered = null;
    closeDialog(true);
    act('simpleView', { enabled: t.checked });
  }
  if (t.id === 'level') act('level', { level: Number(t.value) });
  if (t.id === 'check-training') {
    if (!t.checked && skillFilter === 'needsTraining') skillFilter = 'all';
    act('checkTraining', { enabled: t.checked });
  }
  if (t.id === 'skill-filter') {
    skillFilter = t.value;
    renderSkills();
  }
  if (t.dataset.skillCheck) {
    const s = engine.call('skill', { name: t.dataset.skillCheck });
    const key = skillKey(s);
    if (t.checked) {
      if (!selectionColors.has(key))
        selectionColors.set(
          key,
          engine.call('highlightColor', { assignments: Object.fromEntries(selectionColors) })
        );
      selected.set(key, s);
    } else {
      selected.delete(key);
      selectionColors.delete(key);
    }
    renderSkills();
    for (const n of modal.querySelectorAll('[data-skill-check]')) {
      const item = engine.call('skill', { name: n.dataset.skillCheck });
      n.checked = selected.has(skillKey(item));
      n.style.accentColor = selectionColors.has(skillKey(item))
        ? '#' + catalog.highlightPalette[selectionColors.get(skillKey(item))].hex
        : '';
    }
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
  highlightControl(event.target.closest('[data-skill], [data-highlight-talent]'));
  const t = event.target.closest('[data-talent]');
  if (t && !modal.open) {
    const tip = $('#tooltip');
    const related =
      !state.simpleView && list(engine.call('talentSkills', { id: Number(t.dataset.talent) }));
    tip.innerHTML =
      description(talent(t.dataset.talent)) +
      (related?.length
        ? `<p class="tooltip-skills"><b>Affected skills</b><br>${related.slice(0, 8).map(esc).join(', ')}${related.length > 8 ? ` · +${related.length - 8} more in details` : ''}</p>`
        : '') +
      '<p class="tooltip-hint">Alt-click or Enter: talent details · Right-click: remove</p>';
    tip.hidden = false;
    const rect = t.getBoundingClientRect();
    tip.style.left = `${Math.min(innerWidth - 344, Math.max(8, rect.right + 12))}px`;
    tip.style.top = `${Math.min(innerHeight - tip.offsetHeight - 8, Math.max(8, rect.top))}px`;
  }
});
document.addEventListener('mouseout', (event) => {
  if (
    event.target.closest('[data-skill], [data-highlight-talent]') &&
    !event.relatedTarget?.closest('[data-skill], [data-highlight-talent]')
  ) {
    hovered = null;
    paintHighlights();
  }
  if (event.target.closest('[data-talent]') && !event.relatedTarget?.closest('[data-talent]'))
    $('#tooltip').hidden = true;
});
let viewportWidth = window.innerWidth;
window.addEventListener('resize', () => {
  // Address-bar height changes must not recenter the page during repeated taps.
  if (window.innerWidth === viewportWidth) return;
  viewportWidth = window.innerWidth;
  const graph = $('.graph-scroll');
  if (state && graph?.clientHeight && graph.clientWidth !== graphView.width) render();
  if (talentSheet.open) {
    if (matchMedia('(max-width: 1050px), (pointer: coarse)').matches)
      positionTalentSheet(sheetTalent);
    else closeTalentSheet(false);
  }
});
document.addEventListener('focusin', (event) => {
  highlightControl(event.target.closest('[data-skill], [data-highlight-talent]'));
});
document.addEventListener('focusout', (event) => {
  if (
    event.target.closest('[data-skill], [data-highlight-talent]') &&
    !event.relatedTarget?.closest('[data-skill], [data-highlight-talent]')
  ) {
    hovered = null;
    paintHighlights();
  }
});
modal.addEventListener('cancel', (event) => {
  event.preventDefault();
  closeDialog();
});
modal.addEventListener('close', () => {
  dialogStack.length = 0;
  hovered = null;
  paintHighlights();
  if (modal.returnSelector) {
    const target = document.querySelector(modal.returnSelector);
    if (target && target.getClientRects().length) target.focus({ preventScroll: true });
  }
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && talentSheet.open && !modal.open) {
    event.preventDefault();
    closeTalentSheet();
  }
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
  updateMonitor?.check(true);
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
      updateViaCache: 'none',
    });
    updateMonitor = createUpdateMonitor(registration, ({ kind, manual }) => {
      if (!manual && kind === 'checking') return;
      const wasBusy = updateBusy;
      updateBusy = kind === 'checking' || kind === 'downloading';
      if (!manual && kind === 'current') {
        if (wasBusy) {
          updateMessage = '';
          render();
        }
        return;
      }
      if (!manual && kind === 'failed' && !wasBusy) return;
      updateMessage =
        {
          checking: 'Checking for updates…',
          downloading: 'Downloading the new version…',
          ready: 'A new version is ready. Use Update now above.',
          current: `Version ${catalog.version} is up to date.`,
          failed: 'Could not check or download an update. Try again online.',
        }[kind] || '';
      render();
      if (manual) toast(updateMessage, kind === 'failed');
    });
    await navigator.serviceWorker.ready;
    status = 'Ready offline';
    render();
    let refreshed = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!refreshed) {
        refreshed = true;
        location.reload();
      }
    });
    updateMonitor.check(true);
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) updateMonitor.check(true);
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
      'Saved browser data could not be read. Autosaving is paused to preserve it. Use the recovery download above the calculator.',
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
  openBuildLink();
} catch (e) {
  app.innerHTML = `<div class="loading"><h1>Calculator could not start</h1><p>${esc(e.message)}</p><p>Reload while online to finish downloading the engine. Your saved library is kept.</p><button onclick="location.reload()">Reload</button></div>`;
}
window.addEventListener('hashchange', () => {
  if (engine && catalog) openBuildLink();
});
