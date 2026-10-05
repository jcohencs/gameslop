const $ = (sel) => document.querySelector(sel);
const ICON_BASE = 'https://assets.rpglogs.com/img/warcraft/abilities/';
const CLASS_COLORS = {
  DeathKnight: '#C41E3A', DemonHunter: '#A330C9', Druid: '#FF7C0A', Evoker: '#33937F', Hunter: '#AAD372',
  Mage: '#3FC7EB', Monk: '#00FF98', Paladin: '#F48CBA', Priest: '#FFFFFF', Rogue: '#FFF468',
  Shaman: '#0070DD', Warlock: '#8788EE', Warrior: '#C69B6D',
};
const STATUS_LABEL = { good: 'On par', warn: 'Behind', bad: 'Far behind', over: 'More', neutral: '' };

const state = { code: null, report: null, fightId: null, sourceId: null, wanted: {} };

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const num = (n, d = 0) => (n == null ? '–' : Number(n).toLocaleString('en-US', { maximumFractionDigits: d, minimumFractionDigits: d }));
const compact = (n) => (n == null ? '–' : n >= 1e6 ? `${(n / 1e6).toFixed(2)}M` : n >= 1e3 ? `${(n / 1e3).toFixed(1)}K` : num(n));
const duration = (ms) => `${Math.floor(ms / 60000)}:${String(Math.round((ms % 60000) / 1000)).padStart(2, '0')}`;
const classColor = (c) => CLASS_COLORS[c] ?? '#898781';
const spaced = (s) => String(s ?? '').replace(/([a-z])([A-Z])/g, '$1 $2');

function parseColor(p) {
  if (p >= 100) return ['#e5cc80', '#0b0b0b'];
  if (p >= 99) return ['#e268a8', '#0b0b0b'];
  if (p >= 95) return ['#ff8000', '#0b0b0b'];
  if (p >= 75) return ['#a335ee', '#ffffff'];
  if (p >= 50) return ['#0070ff', '#ffffff'];
  if (p >= 25) return ['#1eff00', '#0b0b0b'];
  return ['#9d9d9d', '#0b0b0b'];
}

// Accepts a full report URL (optionally with #fight=&source=) or a bare code.
function parseInput(raw) {
  const text = raw.trim();
  const m = text.match(/reports\/([a-zA-Z0-9]+)/);
  const code = m ? m[1] : text.match(/^[a-zA-Z0-9]+$/) ? text : null;
  const fight = text.match(/[#&?]fight=(\d+|last)/)?.[1] ?? null;
  const source = text.match(/[#&?]source=(\d+)/)?.[1] ?? null;
  return { code, fight, source: source ? Number(source) : null };
}

async function api(path, params) {
  const res = await fetch(`${path}?${new URLSearchParams(params)}`);
  const json = await res.json();
  if (!res.ok) throw new Error(json.error || `Request failed (${res.status})`);
  return json;
}

function setStatus(text, isError = false) {
  const el = $('#status');
  el.textContent = text;
  el.classList.toggle('error', isError);
}

function iconHtml(icon, name) {
  const fallback = esc((name ?? '?')[0]);
  if (!icon) return `<span class="icon">${fallback}</span>`;
  return `<img class="icon" src="${ICON_BASE}${esc(icon)}" alt="" data-fallback="${fallback}">`;
}

// Broken ability icons (offline, unknown file) become a lettered square.
document.addEventListener('error', (e) => {
  const img = e.target;
  if (img.tagName === 'IMG' && img.dataset.fallback) {
    const span = document.createElement('span');
    span.className = 'icon';
    span.textContent = img.dataset.fallback;
    img.replaceWith(span);
  }
}, true);

async function loadReport(event) {
  event?.preventDefault();
  const { code, fight, source } = parseInput($('#report-input').value);
  if (!code) return setStatus('Paste a Warcraft Logs report link or code.', true);
  const button = $('#load-form button');
  button.disabled = true;
  setStatus('Loading report…');
  $('#result').hidden = true;
  try {
    state.code = code;
    state.report = await api('/api/report', { code });
    state.wanted = { fight, source };
    if (!state.report.fights.length) throw new Error('No boss pulls in this report.');
    const fights = state.report.fights;
    const wantedFight = fight === 'last' ? fights.at(-1) : fights.find((f) => String(f.id) === fight);
    state.fightId = (wantedFight ?? fights.findLast((f) => f.kill) ?? fights.at(-1)).id;
    state.sourceId = null;
    setStatus(`${state.report.title}${state.report.zone ? ` · ${state.report.zone}` : ''}`);
    renderPicker();
    if (source && currentFight().players.some((p) => p.id === source)) selectPlayer(source);
  } catch (err) {
    setStatus(err.message, true);
    $('#picker').hidden = true;
  } finally {
    button.disabled = false;
  }
}

const currentFight = () => state.report.fights.find((f) => f.id === state.fightId);

function renderPicker() {
  $('#picker').hidden = false;
  $('#fights').innerHTML = state.report.fights.map((f) => `
    <button type="button" class="chip" data-fight="${f.id}" aria-pressed="${f.id === state.fightId}">
      <span>${esc(f.difficulty)} ${esc(f.name)}</span>
      <span class="tag ${f.kill ? 'kill' : 'wipe'}">${f.kill ? 'Kill' : `Wipe${f.fightPercentage != null ? ` ${num(f.fightPercentage, 1)}%` : ''}`}</span>
      <small>${duration(f.durationMs)}</small>
    </button>`).join('');
  $('#players').innerHTML = [...currentFight().players]
    .sort((a, b) => (a.className ?? '').localeCompare(b.className ?? '') || a.name.localeCompare(b.name))
    .map((p) => `
      <button type="button" class="chip" data-source="${p.id}" aria-pressed="${p.id === state.sourceId}">
        <span class="dot" style="background:${classColor(p.className)}"></span>
        <span>${esc(p.name)}</span>
        <small>${esc(spaced(p.specName))} ${esc(spaced(p.className))}</small>
      </button>`).join('');
}

$('#fights').addEventListener('click', (e) => {
  const btn = e.target.closest('[data-fight]');
  if (!btn) return;
  state.fightId = Number(btn.dataset.fight);
  const stillHere = currentFight().players.some((p) => p.id === state.sourceId);
  renderPicker();
  if (stillHere) selectPlayer(state.sourceId);
  else $('#result').hidden = true;
});

$('#players').addEventListener('click', (e) => {
  const btn = e.target.closest('[data-source]');
  if (btn) selectPlayer(Number(btn.dataset.source));
});

let analyzeSeq = 0;
async function selectPlayer(sourceId) {
  state.sourceId = sourceId;
  renderPicker();
  const seq = ++analyzeSeq;
  const player = currentFight().players.find((p) => p.id === sourceId);
  setStatus(`Pulling ${player?.name}'s pull and the 99th-percentile sample… (first run per spec/boss takes a few seconds)`);
  history.replaceState(null, '', `#${new URLSearchParams({ report: state.code, fight: state.fightId, source: sourceId })}`);
  try {
    const result = await api('/api/analyze', { code: state.code, fight: state.fightId, source: sourceId });
    if (seq !== analyzeSeq) return;
    setStatus(`${state.report.title}${state.report.zone ? ` · ${state.report.zone}` : ''}`);
    renderResult(result);
  } catch (err) {
    if (seq !== analyzeSeq) return;
    setStatus(err.message, true);
    $('#result').hidden = true;
  }
}

function statusPill(status) {
  return STATUS_LABEL[status] ? `<span class="status-pill ${status}">${STATUS_LABEL[status]}</span>` : '<span></span>';
}

function deltaText(row) {
  if (row.you == null || row.bench == null) return '';
  if (row.lowerIsBetter || !row.bench) return `top: ${num(row.bench, row.decimals)}${row.unit}`;
  const pct = (row.you / row.bench) * 100;
  return `top: ${row.key === 'amount' ? compact(row.bench) : num(row.bench, row.decimals) + row.unit} · ${num(pct, 0)}%`;
}

function barRows(rows, { unit = '', decimals = 1, max, tip }) {
  if (!rows.length) return '<p class="empty">Nothing to compare.</p>';
  const scale = max ?? Math.max(...rows.map((r) => Math.max(r.you, r.bench)), 0.0001) * 1.08;
  return `<div class="legend" aria-hidden="true"><span><i class="swatch-you"></i>You</span><span><i class="swatch-bench"></i>Top players (median)</span></div>
  <div class="rows">${rows.map((r) => `
    <div class="row" data-tip="${esc(tip(r))}">
      <div class="name">${iconHtml(r.icon, r.name)}<span>${esc(r.name)}</span></div>
      <div class="track" aria-hidden="true">
        <div class="bar" style="width:${Math.min(100, (r.you / scale) * 100)}%"></div>
        <div class="tick" style="left:${Math.min(100, (r.bench / scale) * 100)}%"></div>
      </div>
      <div class="nums"><b>${num(r.you, decimals)}${unit}</b> <span class="b">/ ${num(r.bench, decimals)}${unit}</span></div>
      ${statusPill(r.status)}
    </div>`).join('')}</div>`;
}

function renderResult({ player, fight, benchmark, comparison }) {
  const el = $('#result');
  const amountRow = comparison.summary.find((s) => s.key === 'amount');
  const [parseBg, parseInk] = parseColor(player.rankPercent ?? 0);
  const pctLabel = benchmark.percentile ? `${benchmark.percentile}th percentile` : 'top-ranked';
  const benchDesc = benchmark.percentile
    ? `${benchmark.size} ${esc(spaced(player.specName))} ${esc(spaced(player.className))} logs around rank #${num(benchmark.position)} of ${num(benchmark.totalRanked)} (the ${pctLabel})`
    : `${benchmark.size} of the top-ranked ${esc(spaced(player.specName))} ${esc(spaced(player.className))} logs (the API didn't report a total, so this is the top of the leaderboard)`;

  el.innerHTML = `
    <div class="card hero">
      <div>
        <div class="who" style="color:${player.className === 'Priest' ? 'var(--ink)' : classColor(player.className)}">${esc(player.name)}</div>
        <div class="meta">${esc(spaced(player.specName))} ${esc(spaced(player.className))} · ${esc(fight.difficulty)} ${esc(fight.name)} · ${fight.kill ? 'Kill' : 'Wipe'} ${duration(fight.durationMs)}</div>
      </div>
      <div class="figure">
        <div class="big">${compact(amountRow.you)} <span style="font-size:18px;font-weight:600">${esc(amountRow.label)}</span>${player.rankPercent != null ? `<span class="parse" style="background:${parseBg};color:${parseInk}" title="Warcraft Logs parse">${num(player.rankPercent)}</span>` : ''}</div>
        <div class="vs">vs ${compact(amountRow.bench)} for the ${pctLabel} (${num((amountRow.you / amountRow.bench) * 100, 0)}%)</div>
      </div>
    </div>

    <div class="tiles">${comparison.summary.filter((s) => s.key !== 'amount').map((s) => `
      <div class="tile">
        <div class="label">${esc(s.label)}</div>
        <div class="value">${num(s.you, s.key === 'deaths' ? 0 : s.decimals)}${s.unit}</div>
        <div class="bench">${deltaText(s)}</div>
        ${statusPill(s.status)}
      </div>`).join('')}
    </div>

    <div class="card">
      <h3>What to work on</h3>
      <p class="hint">Biggest gaps against the ${pctLabel} sample, most important first.</p>
      ${comparison.takeaways.length
        ? `<ul class="takeaways">${comparison.takeaways.map((t) => `<li><span class="sev sev-${t.severity}">${['', 'Note', 'Fix', 'Big'][t.severity]}</span><span>${esc(t.text)}</span></li>`).join('')}</ul>`
        : '<p class="empty">No major gaps. This pull looks like a top-percentile one.</p>'}
    </div>

    <div class="card">
      <h3>Casts per minute</h3>
      <p class="hint">Per-minute so fight length doesn't skew it. Under-casting a core ability is usually the easiest win.</p>
      ${barRows(comparison.casts, { decimals: 1, tip: (r) => `${r.name}: you ${num(r.you, 2)}/min, top median ${num(r.bench, 2)}/min${r.presence ? ` (${num(r.presence * 100)}% of top players cast it)` : ' (top players don’t use this)'}` })}
    </div>

    <div class="card">
      <h3>${player.metric === 'hps' ? 'Healing' : 'Damage'} breakdown</h3>
      <p class="hint">Share of your total from each ability.</p>
      ${barRows(comparison.abilities, { unit: '%', decimals: 1, tip: (r) => `${r.name}: ${num(r.you, 1)}% of your total vs ${num(r.bench, 1)}% for top players` })}
    </div>

    <div class="card">
      <h3>Buff uptime</h3>
      <p class="hint">Includes externals like Bloodlust and Power Infusion, which depend on your raid.</p>
      ${barRows(comparison.buffs, { unit: '%', decimals: 0, max: 100, tip: (r) => `${r.name}: ${num(r.you, 1)}% uptime vs ${num(r.bench, 1)}%` })}
    </div>

    <div class="card">
      <h3>Who you're compared against</h3>
      <p class="hint">${benchDesc}. Values above are the median across these pulls (median length ${duration(benchmark.durationMs)}).</p>
      <ul class="sample">${benchmark.sample.map((s) => `
        <li>${s.code && !s.code.startsWith('DEMO')
          ? `<a href="https://www.warcraftlogs.com/reports/${encodeURIComponent(s.code)}#fight=${s.fightId}" target="_blank" rel="noopener">${esc(s.name)}</a>`
          : esc(s.name)}${s.server ? ` <small>${esc(s.server)}</small>` : ''} <span class="amt">${compact(s.amount)}${s.analyzed ? '' : ' (log unavailable)'}</span></li>`).join('')}
      </ul>
    </div>`;
  el.hidden = false;
}

// Hover tooltip for bar rows.
const tooltip = $('#tooltip');
document.addEventListener('mousemove', (e) => {
  const row = e.target.closest?.('[data-tip]');
  if (!row) { tooltip.hidden = true; return; }
  tooltip.textContent = row.dataset.tip;
  tooltip.hidden = false;
  const x = Math.min(e.clientX + 14, window.innerWidth - tooltip.offsetWidth - 8);
  tooltip.style.left = `${x}px`;
  tooltip.style.top = `${e.clientY + 16}px`;
});

$('#load-form').addEventListener('submit', loadReport);

(async function init() {
  try {
    const config = await api('/api/config', {});
    $('#demo-banner').hidden = !config.demo;
    const hash = new URLSearchParams(location.hash.slice(1));
    if (hash.get('report')) {
      $('#report-input').value = `https://www.warcraftlogs.com/reports/${hash.get('report')}#fight=${hash.get('fight') ?? ''}&source=${hash.get('source') ?? ''}`;
      loadReport();
    } else if (config.demo) {
      $('#report-input').value = 'https://www.warcraftlogs.com/reports/DEMOreport1#fight=3&source=1';
    }
  } catch {
    // Config is cosmetic; the form still works.
  }
})();
