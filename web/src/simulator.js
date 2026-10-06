// Native and browser interfaces receive their input definitions and results from Lua.
export function createSimulatorUI({
  engine,
  state,
  openDialog,
  showShare,
  showImport,
  persist,
  toast,
}) {
  const $ = (selector) => document.querySelector(selector);
  const esc = (v) =>
    String(v ?? '').replace(
      /[&<>"']/g,
      (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]
    );
  const list = (v) => Object.values(v || {});
  const fmt = (n) => Number(n || 0).toLocaleString(undefined, { maximumFractionDigits: 1 });
  const range = (a, b) => (Math.abs(a - b) < 0.05 ? fmt(a) : `${fmt(a)}–${fmt(b)}`);
  const button = (text, action, data = '', cls = '') =>
    `<button type="button" data-action="${action}" ${data} class="${cls}">${text}</button>`;
  const image = (icon) =>
    `<img src="${new URL(`generated/icons/${encodeURIComponent(icon)}.jpg`, document.baseURI)}" alt="" width="48" height="48">`;
  let simulation, character, editingSlot;

  function options(key) {
    if (key === 'weaponType' || key === 'racialWeaponType')
      return list(engine().call('character').weaponTypes);
    if (key === 'form')
      return [
        { key: 'caster', name: 'Caster' },
        { key: 'cat', name: 'Cat' },
        { key: 'bear', name: 'Bear' },
      ];
    if (key === 'effectMode')
      return [
        { key: 'damage', name: 'Damage' },
        { key: 'healing', name: 'Healing' },
      ];
    return [
      { key: 'other', name: 'Other creature' },
      { key: 'beast', name: 'Beast' },
      { key: 'elemental', name: 'Elemental' },
      { key: 'humanoid', name: 'Humanoid' },
      { key: 'giant', name: 'Giant' },
    ];
  }
  function input(spec) {
    const value = simulation.values[spec.key];
    const override = Object.hasOwn(simulation.overrides, spec.key);
    const id = `stat-${spec.key}`;
    const help = `help-${spec.key}`;
    const mark = override ? '<span class="override-label">Temporary override</span>' : '';
    if (spec.type === 'boolean')
      return `<label class="pin sim-toggle"><input type="checkbox" data-sim-stat="${spec.key}" aria-label="${esc(spec.label)}" ${value ? 'checked' : ''} aria-describedby="${help}">${esc(spec.label)}<small id="${help}">${esc(spec.help)}</small></label>`;
    if (spec.type === 'choice')
      return `<label class="sim-field" for="${id}">${esc(spec.label)}${mark}<select id="${id}" data-sim-stat="${spec.key}" aria-label="${esc(spec.label)}" aria-describedby="${help}">${(list(spec.choices).length ? list(spec.choices) : options(spec.key)).map((c) => `<option value="${c.key}" ${c.key === value ? 'selected' : ''}>${esc(c.name)}</option>`).join('')}</select><small id="${help}">${esc(spec.help)}</small></label>`;
    return `<label class="sim-field ${override ? 'has-override' : ''}" for="${id}">${esc(spec.label)}${mark}<input id="${id}" type="number" data-sim-stat="${spec.key}" aria-label="${esc(spec.label)}" value="${value ?? ''}" step="any" min="${spec.min}" max="${spec.max}" placeholder="Automatic" aria-describedby="${help}"><small id="${help}">${esc(spec.help)}</small></label>`;
  }
  function renderInputs(specs) {
    const focus = document.activeElement?.id;
    const ids =
      list(specs)
        .map((s) => s.key)
        .join(',') + `:${simulation.values.manual}`;
    // Preserve the active input and caret while the user types.
    if (simulation.inputSignature !== ids) {
      const groups = (names) =>
        list(specs)
          .filter((s) => names.includes(s.group))
          .map(input)
          .join('');
      $('#sim-character-inputs').innerHTML = groups(['character']);
      $('#sim-target-inputs').innerHTML = groups(['target', 'condition']);
      $('#sim-advanced-inputs').innerHTML = groups(['advanced']);
      simulation.inputSignature = ids;
      if (focus) document.getElementById(focus)?.focus();
    }
    $('#sim-character-inputs').hidden = !list(specs).some((s) => s.group === 'character');
    $('#sim-target-section').hidden = !list(specs).some((s) =>
      ['target', 'condition'].includes(s.group)
    );
    for (const node of document.querySelectorAll('[data-sim-stat]')) {
      const key = node.dataset.simStat;
      if (node !== document.activeElement) {
        if (node.type === 'checkbox') node.checked = !!simulation.values[key];
        else node.value = simulation.values[key] ?? '';
      }
      const label = node.closest('.sim-field');
      label?.classList.toggle('has-override', Object.hasOwn(simulation.overrides, key));
      if (
        label &&
        !label.querySelector('.override-label') &&
        Object.hasOwn(simulation.overrides, key)
      )
        label.insertAdjacentHTML(
          'afterbegin',
          '<span class="override-label">Temporary override</span>'
        );
    }
  }
  function show(name, rank, overrides = {}) {
    if (!state().simulationEnabled) {
      toast('Enable the experimental simulator in Settings.');
      return;
    }
    const skill = engine().call('skill', { name });
    simulation = { name, rank, skill, overrides, values: {}, inputSignature: '' };
    const ranks = list(skill.ranks);
    const savedSimulation = simulation;
    openDialog(
      `Experimental simulator · ${name}`,
      `<section class="sim-character-banner" aria-label="Central character"><div class="sim-character-portrait">${image(state().view.classID ? engine().call('character').classIcon : 'class_druid')}</div><div><span class="eyebrow">YOUR CHARACTER</span><h3 id="sim-character-name"></h3><p id="sim-character-summary" class="muted"></p><small id="sim-character-source"></small></div>${button('Edit character', 'character-sheet')}</section><div class="sim-skill-heading"><div><span class="eyebrow">ONE USE · ONE TARGET</span><h3>${image(skill.icon)}${esc(skill.name)}</h3></div><label>Rank<select id="sim-rank">${ranks.map((r, i) => `<option value="${i + 1}" ${i + 1 === rank ? 'selected' : ''}>${esc(r.label || 'Ability')} · level ${r.level}${r.talentGranted ? ' · talent unlock' : ''}</option>`).join('')}</select></label></div><div id="sim-live-summary" class="sim-live-summary" aria-live="polite"></div><div class="sim-workbench"><section class="sim-input-pane"><p class="sim-local-note">Inputs come from your character. Changes here are temporary for this skill; the character sheet stays unchanged.</p><div id="sim-character-inputs" class="sim-fields"></div><section id="sim-target-section"><h3>Target & conditions</h3><div id="sim-target-inputs" class="sim-fields"></div></section><details class="sim-advanced"><summary>Advanced · scaling and manual amounts</summary><p class="muted">Blank coefficients use captured data. Supplied values are explicit assumptions. Only applicable inputs appear.</p><label class="pin"><input type="checkbox" data-sim-stat="manual">Replace captured amounts with a manual model</label><div id="sim-advanced-inputs" class="sim-fields"></div></details></section><section id="sim-results" class="sim-output-pane" aria-live="polite" aria-atomic="true"></section></div><div class="dialog-actions">${button('Reset skill overrides', 'reset-sim')}${button('Copy these inputs', 'share-stats')}${button('Paste skill inputs', 'paste-sim-inputs')}${button('Back to skill', 'related-skill', `data-name="${esc(name)}"`)}</div>`,
      true,
      () => {
        simulation = savedSimulation;
        render();
      }
    );
    render();
  }
  function render() {
    if (!simulation || !$('#sim-results')) return;
    const payload = {
      name: simulation.name,
      rank: simulation.rank,
      overrides: simulation.overrides,
    };
    const saved = engine().call('statsForSkill', payload);
    simulation.values = { ...saved.state, ...simulation.overrides };
    const sheet = saved.character;
    $('#sim-character-name').textContent = `${sheet.sheet.name} · level ${sheet.level}`;
    $('#sim-character-summary').textContent =
      `Power ${fmt(sheet.totals.power)} · Healing ${fmt(sheet.totals.healing)} · Melee AP ${fmt(sheet.totals.attackPower)} · Ranged AP ${fmt(sheet.totals.rangedAP)}`;
    $('#sim-character-source').textContent = sheet.source;
    try {
      const r = engine().call('simulate', payload);
      const baseline = engine().call('simulate', { ...payload, withTalents: false });
      simulation.result = r;
      $('#sim-live-summary').innerHTML =
        `<span>Expected total<strong>${fmt(r.expected)}</strong></span><span class="badge">${esc(r.confidence)}</span>`;
      simulation.values = { ...r.state };
      renderInputs(r.inputs);
      const delta = baseline.expected > 0 ? (r.expected / baseline.expected - 1) * 100 : 0;
      $('#sim-results').innerHTML =
        `<div class="sim-result-heading"><span class="badge ${r.confidence === 'Partial estimate' ? 'partial' : ''}">${esc(r.confidence)}</span><span class="muted">${esc(r.parsed.displayKind || r.parsed.kind)} · full effect</span></div><div class="result-cards simulator-cards"><article class="expected-card"><small>Expected total</small><strong>${fmt(r.expected)}</strong><span>Average including critical effects and chance to land</span></article><article><small>Non-critical total</small><strong>${range(r.normalMin, r.normalMax)}</strong><span>Successful use · all ticks complete</span></article><article><small>Every eligible effect crits</small><strong>${r.critEligible ? range(r.criticalMin, r.criticalMax) : 'Cannot crit'}</strong><span>${r.critEligible ? 'An upper scenario; each tick rolls separately' : 'Critical chance does not apply'}</span></article></div><div class="sim-comparison"><span>Without selected talents <b>${fmt(baseline.expected)}</b></span><span aria-hidden="true">→</span><span>This build <b>${fmt(r.expected)}</b></span><strong>${delta >= 0 ? '+' : ''}${fmt(delta)}%</strong></div>${r.perSecond !== undefined ? `<p class="muted">${fmt(r.perSecond)} ${esc(r.parsed.displayKind || r.parsed.kind)} / sec over ${fmt(r.duration)} sec. Full duration only; this is not rotation DPS.</p>` : ''}<div class="sim-effects">${list(
          r.breakdown
        )
          .map(
            (b) =>
              `<article><h4>${esc(b.label)}</h4><strong>${range(b.totalLow, b.totalHigh)}</strong><p>${b.part === 'periodic' ? `${b.ticks} ticks${b.interval > 0 ? ` · every ${fmt(b.interval)} sec` : ' · timing unverified'}` : 'One impact'}</p><small>${b.critEligible ? `${fmt(b.crit)}% crit · ×${fmt(b.critMultiplier)}` : 'Cannot crit'} · ${fmt(b.hit)}% lands</small></article>`
          )
          .join(
            ''
          )}</div><details class="sim-calculation"><summary>How this is calculated</summary><p>Each component is calculated separately. Power scaling is applied per effect, then bonuses, damage reduction and critical chances.</p>${list(
          r.breakdown
        )
          .map(
            (b) =>
              `<article><h4>${esc(b.label)} · spell ${b.sourceSpell}</h4><p class="formula">${esc(b.formula)}</p><p class="formula">${esc(b.averageFormula)}</p><p class="muted">Power coefficient: ${fmt(b.coefficient * 100)}% ${b.part === 'periodic' ? 'per tick' : 'for the direct effect'} · AP coefficient: ${fmt((b.apCoefficient || 0) * 100)}% ${b.part === 'periodic' ? 'per tick' : 'direct'}${b.levelBonus ? ` · includes ${fmt(b.levelBonus)} base growth from level` : ''}.</p></article>`
          )
          .join(
            ''
          )}<p class="muted">Selected flat percentage bonuses add within the modeled category. Other bonus and racial modifiers multiply separately. Tick timing, critical eligibility and scaling come from the cited client snapshot unless overridden.</p></details><details class="sim-evidence"><summary>Included bonuses & data sources</summary><h4>Talents</h4>${
          list(r.modifiers.evidence)
            .map((e) => `<p><b>${esc(e.name)} · rank ${e.rank}</b><br>${esc(e.text)}</p>`)
            .join('') || '<p class="muted">No selected talent changes this modeled amount.</p>'
        }<h4>Racials</h4><p>${esc(list(r.racials).join(', ') || 'No racial bonus applies to this use.')}</p>${list(r.modifiers.omitted).length ? `<p><b>Other interactions not included:</b> ${esc(list(r.modifiers.omitted).join(', '))}</p>` : ''}<p class="muted">${esc(r.source)}</p><ul>${list(
          r.sources
        )
          .map(
            (s) =>
              `<li><a href="${esc(s.url)}" target="_blank" rel="noopener">${esc(s.label)}</a></li>`
          )
          .join(
            ''
          )}</ul></details><aside class="sim-coverage"><h4>Accuracy & scope</h4>${r.statsNote ? `<p>${esc(r.statsNote)}</p>` : ''}<ul>${list(
          r.warnings
        )
          .map((w) => `<li>${esc(w)}</li>`)
          .join('')}</ul><p>${esc(r.limits)}</p></aside>`;
    } catch (error) {
      simulation.result = null;
      renderInputs(saved.inputs);
      $('#sim-results').innerHTML =
        `<p class="callout">${esc(error.message)}</p><p class="muted">Your character is kept. Utility, pet and scripted effects may have no supported amount. Advanced lets you supply an explicit manual model.</p>`;
    }
  }
  function characterInputs(c) {
    return list(c.fields)
      .map(
        (f) =>
          `<label class="character-field">${esc(f.label)}<span><input data-character-stat="${f.key}" id="character-${f.key}" type="number" value="${f.value}" min="0" max="${f.max || 100000}" step="any" ${f.editable ? '' : 'readonly'} aria-label="${esc(f.label)} input"><output data-character-total="${f.key}" aria-label="${esc(f.label)} resulting total">${fmt(f.total)}</output></span></label>`
      )
      .join('');
  }
  function showCharacter() {
    if (!state().simulationEnabled) {
      toast('Enable the experimental simulator in Settings.');
      return;
    }
    character = engine().call('character');
    const c = character;
    openDialog(
      'Character · experimental simulator',
      `<div class="character-identity">${image(c.classIcon)}<div><span class="eyebrow">${esc(c.identity)} · LEVEL ${c.level}</span><label for="character-name">Character name<input id="character-name" maxlength="48" value="${esc(c.sheet.name)}"></label></div></div><div class="character-modes" role="group" aria-label="Character stats source">${[
        ['gear', 'Base + custom gear'],
        ['manual', 'Overall stats'],
        ['captured', 'Live capture'],
      ]
        .map(
          ([key, text]) =>
            `<button type="button" data-action="character-mode" data-mode="${key}" aria-pressed="${c.sheet.mode === key}" ${key === 'captured' && !c.sheet.capture ? 'disabled' : ''}>${text}</button>`
        )
        .join(
          ''
        )}</div><p class="sim-local-note" id="character-source"></p><div class="character-workspace"><section class="paper-doll" aria-label="Equipment slots"><img class="character-art" src="${new URL('generated/character.svg', document.baseURI)}" alt="Armored character illustration">${list(
        c.slots
      )
        .map(
          (s, i) =>
            `<button type="button" class="gear-slot gear-${i < 7 ? 'left' : i < 14 ? 'right' : 'weapon'} ${c.sheet.gear[s.key] ? 'equipped' : ''}" style="--slot:${i < 7 ? i : i < 14 ? i - 7 : i - 14}" data-action="edit-gear" data-slot="${s.key}" aria-label="${esc(s.name)}: ${esc(c.sheet.gear[s.key]?.name || 'Empty')}"><span class="slot-glyph" aria-hidden="true">◇</span><span><b>${esc(s.name)}</b><small>${esc(c.sheet.gear[s.key]?.name || 'Create item')}</small></span></button>`
        )
        .join(
          ''
        )}<div class="paper-doll-resources"><span>Health <b data-sheet-health>${fmt(c.totals.health)}</b></span><span>Mana <b data-sheet-mana>${fmt(c.totals.mana)}</b></span></div></section><section class="character-stats" aria-label="Character stats"><div class="character-stats-heading"><h3>Stats</h3><span>Input → resulting total</span></div><div class="character-fields">${characterInputs(c)}</div><label class="sim-field">Overall weapon type<select id="character-weapon-type">${list(
        c.weaponTypes
      )
        .map(
          (t) =>
            `<option value="${t.key}" ${t.key === c.sheet.weaponType ? 'selected' : ''}>${esc(t.name)}</option>`
        )
        .join('')}</select></label>${
        list(c.forms).length
          ? `<label class="sim-field">Shapeshift form<select id="character-form">${list(c.forms)
              .map(
                (f) =>
                  `<option value="${f.key}" ${f.key === c.sheet.form ? 'selected' : ''}>${esc(f.name)}</option>`
              )
              .join('')}</select></label>`
          : ''
      }<div id="character-notes"></div></section></div><aside class="callout">Live character import is available in the WoW addon. Use Import my talents & skills there, then copy the character string and paste it here. It includes trained skill ranks; the Trained filter shows that capture independently of your planned level. Captured equipment is shown for reference; its bonuses are already in reported totals.</aside><div class="dialog-actions">${button('Copy character & gear', 'share-character', '', 'primary')}${button('Copy stats only', 'share-character-stats')}${button('Paste character / stats', 'import')}${simulation ? button('Back to skill simulator', 'back-simulator') : ''}</div>`,
      true,
      showCharacter
    );
    refreshCharacter();
  }
  function refreshCharacter() {
    const c = engine().call('character');
    character = c;
    if (!$('#character-source')) return;
    $('#character-source').textContent =
      `${c.source}. ${c.sheet.mode === 'gear' ? 'Enter extra bonuses beyond the base and gear slots.' : c.sheet.mode === 'captured' ? 'Captured totals already include gear, buffs and learned talents.' : 'Enter overall stats before the modeled talent and racial passives.'} Gold numbers show the resulting total.`;
    for (const f of list(c.fields)) {
      const output = document.querySelector(`[data-character-total="${f.key}"]`);
      if (output) output.value = fmt(f.total);
    }
    $('[data-sheet-health]').textContent = fmt(c.totals.health);
    $('[data-sheet-mana]').textContent = fmt(c.totals.mana);
    $('#character-notes').innerHTML =
      `<p><b>Applied stat passives:</b> ${esc(list(c.passives.included).join(', ') || 'Skill-specific bonuses appear in the simulator.')}</p><details><summary>Base stats, conversions & limits</summary>${list(
        c.warnings
      )
        .map((w) => `<p>${esc(w)}</p>`)
        .join(
          ''
        )}<p>Each class keeps its own character workspace. Race, level and modeled passives follow the displayed build. The gear reference uses base attributes and conventional stat conversions; use live totals for measured comparisons.</p></details>`;
  }
  function saveCharacter() {
    engine().call('characterSave', { sheet: character.sheet });
    persist();
    refreshCharacter();
  }
  function showGear(slotKey) {
    character = engine().call('character');
    const slot = list(character.slots).find((s) => s.key === slotKey);
    if (!slot) return;
    editingSlot = slotKey;
    const item = character.sheet.gear[slotKey] || {
      name: `Custom ${slot.name}`,
      stats: {},
      low: 0,
      high: 0,
      speed: 0,
      weaponType: 'none',
    };
    openDialog(
      `Custom gear · ${slot.name}`,
      `<p class="muted">Create an item with listed bonuses. Procs and set effects need explicit assumptions.</p><label class="sim-field">Item name<input id="gear-name" maxlength="80" value="${esc(item.name)}"></label><div class="gear-fields sim-fields">${list(
        character.gearFields
      )
        .map(
          (f) =>
            `<label class="sim-field">${esc(f.key === 'hit' ? 'Hit chance bonus (%)' : f.label)}<input type="number" data-gear-stat="${f.key}" value="${item.stats[f.key] || 0}" min="0" max="${f.max || 100000}" step="any"></label>`
        )
        .join('')}</div>${
        slot.weapon
          ? `<h3>Weapon</h3><p class="muted">Raw damage excludes Attack Power. The shared engine adds AP using weapon speed.</p><div class="sim-fields">${[
              ['low', 'Raw damage · low'],
              ['high', 'Raw damage · high'],
              ['speed', 'Speed (seconds)'],
            ]
              .map(
                ([key, text]) =>
                  `<label class="sim-field">${text}<input type="number" data-gear-weapon="${key}" value="${item[key] || 0}" min="0" step="any"></label>`
              )
              .join('')}</div><label class="sim-field">Weapon type<select id="gear-type">${list(
              character.weaponTypes
            )
              .map(
                (t) =>
                  `<option value="${t.key}" ${t.key === item.weaponType ? 'selected' : ''}>${esc(t.name)}</option>`
              )
              .join('')}</select></label>`
          : ''
      }<p id="gear-error" class="form-error" role="alert"></p><div class="dialog-actions">${button('Equip custom item', 'equip-gear', '', 'primary')}${button('Remove item', 'remove-gear')}${button('Back to character', 'character-sheet')}</div>`,
      true
    );
  }
  function action(name, node) {
    switch (name) {
      case 'simulate':
        show(node.dataset.name, Number(node.dataset.rank));
        return true;
      case 'character-sheet':
        showCharacter();
        return true;
      case 'back-simulator':
        if (simulation) show(simulation.name, simulation.rank, simulation.overrides);
        return true;
      case 'reset-sim':
        simulation.overrides = {};
        simulation.inputSignature = '';
        render();
        return true;
      case 'paste-sim-inputs':
        openDialog(
          'Paste simulator inputs',
          `<p>These inputs apply to <b>${esc(simulation.name)}</b> temporarily. Your central character, equipment and talent build stay unchanged.</p><label class="field-label" for="sim-import-code">Stats string (FS1 / FS2)</label><textarea id="sim-import-code" rows="5" maxlength="65536" spellcheck="false"></textarea><p id="sim-import-error" class="form-error" role="alert"></p><div class="dialog-actions">${button('Use temporary inputs', 'sim-import-load', '', 'primary')}${button('Back to simulator', 'sim-import-cancel')}</div>`
        );
        return true;
      case 'sim-import-load':
        try {
          const overrides = engine().call('simulationInputs', {
            name: simulation.name,
            rank: simulation.rank,
            code: $('#sim-import-code').value,
          });
          show(simulation.name, simulation.rank, overrides);
        } catch (e) {
          $('#sim-import-error').textContent = e.message;
        }
        return true;
      case 'sim-import-cancel':
        show(simulation.name, simulation.rank, simulation.overrides);
        return true;
      case 'share-stats':
        showShare('stats', {
          state: simulation.result?.state || simulation.values,
          skillName: simulation.name,
        });
        return true;
      case 'share-character':
        showShare('character');
        return true;
      case 'share-character-stats':
        showShare('stats');
        return true;
      case 'character-mode': {
        engine().call('characterMode', { mode: node.dataset.mode });
        persist();
        showCharacter();
        return true;
      }
      case 'edit-gear':
        showGear(node.dataset.slot);
        return true;
      case 'remove-gear':
        delete character.sheet.gear[editingSlot];
        saveCharacter();
        showCharacter();
        return true;
      case 'equip-gear': {
        const item = {
          name: $('#gear-name').value,
          stats: {},
          weaponType: $('#gear-type')?.value || 'none',
          low: 0,
          high: 0,
          speed: 0,
        };
        for (const input of document.querySelectorAll('[data-gear-stat]'))
          item.stats[input.dataset.gearStat] = Number(input.value);
        for (const input of document.querySelectorAll('[data-gear-weapon]'))
          item[input.dataset.gearWeapon] = Number(input.value);
        try {
          character.sheet.gear[editingSlot] = item;
          saveCharacter();
          showCharacter();
        } catch (e) {
          $('#gear-error').textContent = e.message;
        }
        return true;
      }
    }
    return false;
  }
  function inputEvent(node) {
    if (node.dataset.simStat && simulation) {
      const key = node.dataset.simStat;
      if (node.type === 'checkbox') simulation.overrides[key] = node.checked;
      else if (node.value === '') delete simulation.overrides[key];
      else {
        if (!node.validity.valid) return true;
        simulation.overrides[key] = node.tagName === 'SELECT' ? node.value : Number(node.value);
      }
      if (key === 'manual' && node.checked) {
        const model = engine().call('statsForSkill', {
          name: simulation.name,
          rank: simulation.rank,
        }).parsed;
        simulation.overrides.baseMin = model?.min || 0;
        simulation.overrides.baseMax = model?.max || 0;
        simulation.overrides.periodicBase = model?.periodic || 0;
      }
      render();
      return true;
    }
    if (node.dataset.characterStat) {
      if (!node.validity.valid || character.sheet.mode === 'captured') return true;
      character.sheet.stats[node.dataset.characterStat] = Number(node.value);
      saveCharacter();
      return true;
    }
    if (node.id === 'character-name') {
      character.sheet.name = node.value;
      saveCharacter();
      return true;
    }
    return false;
  }
  function changeEvent(node) {
    if (node.id === 'sim-rank') {
      simulation.rank = Number(node.value);
      simulation.overrides = {};
      simulation.inputSignature = '';
      render();
      return true;
    }
    if (node.id === 'character-weapon-type' || node.id === 'character-form') {
      character.sheet[node.id === 'character-form' ? 'form' : 'weaponType'] = node.value;
      saveCharacter();
      return true;
    }
    return false;
  }
  return { action, inputEvent, changeEvent, show, showCharacter, render };
}
