// Pure functions: turn raw Warcraft Logs tables into stats, aggregate a
// benchmark sample, and compare a player against it. No I/O here.

export const ROLES = ['tanks', 'healers', 'dps'];

export function median(values) {
  const v = values.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (!v.length) return null;
  const mid = Math.floor(v.length / 2);
  return v.length % 2 ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

// Actor icons look like "DeathKnight-Blood".
export function specFromIcon(icon) {
  const [className, specName] = String(icon ?? '').split('-');
  return { className: className || null, specName: specName || null };
}

export function serverName(server) {
  return typeof server === 'string' ? server : server?.name ?? null;
}

// Where in the leaderboard the Nth percentile sits. Rankings are sorted best
// first, so the 99th percentile is the entry ~1% of the way down.
export function percentileTarget(count, percentile = 99, pageSize = 100) {
  const position = Math.max(1, Math.ceil((count * (100 - percentile)) / 100));
  return { position, page: Math.ceil(position / pageSize), index: (position - 1) % pageSize };
}

// A window of `size` rankings centered on `index`, clamped to the list.
export function pickSample(rankings, index, size) {
  if (!rankings?.length) return [];
  const start = Math.max(0, Math.min(rankings.length - size, index - Math.floor(size / 2)));
  return rankings.slice(start, start + size);
}

// report.rankings(fightIDs) → this character's parse, class, spec and role.
export function findRanking(rankingsJson, name) {
  const fights = Array.isArray(rankingsJson) ? rankingsJson : rankingsJson?.data ?? [];
  for (const fight of fights) {
    for (const role of ROLES) {
      const c = fight.roles?.[role]?.characters?.find((ch) => ch.name === name);
      if (c) {
        return {
          role,
          className: c.class,
          specName: c.spec,
          amount: c.amount,
          rankPercent: c.rankPercent ?? null,
          bracketPercent: c.bracketPercent ?? null,
        };
      }
    }
  }
  return null;
}

const entriesOf = (table) => table?.entries ?? [];
const perMin = (n, ms) => (ms > 0 ? n / (ms / 60000) : 0);

// One player's stats for one fight. `tables` is what source.getPlayerFight /
// getBenchmarkFights return.
export function extractStats(tables, { sourceId, name, role = 'dps', amount = null }) {
  const { fight } = tables;
  const durationMs = fight ? fight.endTime - fight.startTime : tables.damage?.totalTime ?? 0;
  const isHealer = role === 'healers';
  const matches = (e) => e.id === sourceId || (sourceId == null && e.name === name);

  const metricEntry = entriesOf(isHealer ? tables.healing : tables.damage).find(matches);
  const total = metricEntry?.total ?? 0;

  const abilityEntries = entriesOf(isHealer ? tables.healingAbilities : tables.damageAbilities);
  const abilityTotal = abilityEntries.reduce((s, e) => s + (e.total ?? 0), 0);
  const abilities = {};
  for (const e of abilityEntries) {
    abilities[e.guid] = { guid: e.guid, name: e.name, icon: e.abilityIcon, value: abilityTotal ? (e.total / abilityTotal) * 100 : 0 };
  }

  const casts = {};
  let castCount = 0;
  for (const e of entriesOf(tables.casts)) {
    castCount += e.total ?? 0;
    casts[e.guid] = { guid: e.guid, name: e.name, icon: e.abilityIcon, value: perMin(e.total ?? 0, durationMs) };
  }

  const buffs = {};
  const buffTime = tables.buffs?.totalTime || durationMs;
  for (const a of tables.buffs?.auras ?? []) {
    buffs[a.guid] = { guid: a.guid, name: a.name, icon: a.abilityIcon, value: buffTime ? Math.min(100, (a.totalUptime / buffTime) * 100) : 0 };
  }

  return {
    durationMs,
    amount: amount ?? (durationMs ? total / (durationMs / 1000) : 0),
    activeTimePct: metricEntry?.activeTime != null && durationMs ? Math.min(100, (metricEntry.activeTime / durationMs) * 100) : null,
    itemLevel: metricEntry?.itemLevel ?? null,
    deaths: entriesOf(tables.deaths).filter(matches).length,
    cpm: perMin(castCount, durationMs),
    abilities,
    casts,
    buffs,
  };
}

// Median of each per-ability stat across the sample. An ability only makes the
// benchmark if at least half the sample has it (absent counts as 0).
function aggregateMap(maps) {
  const byGuid = new Map();
  for (const m of maps) {
    for (const item of Object.values(m)) {
      if (!byGuid.has(item.guid)) byGuid.set(item.guid, { ...item, values: [] });
      byGuid.get(item.guid).values.push(item.value);
    }
  }
  const out = {};
  for (const [guid, item] of byGuid) {
    const presence = item.values.length / maps.length;
    if (presence < 0.5) continue;
    const values = [...item.values, ...Array(maps.length - item.values.length).fill(0)];
    out[guid] = { guid, name: item.name, icon: item.icon, value: median(values), presence };
  }
  return out;
}

export function aggregateBenchmark(statsList) {
  if (!statsList.length) return null;
  const pick = (k) => median(statsList.map((s) => s[k]));
  return {
    size: statsList.length,
    durationMs: pick('durationMs'),
    amount: pick('amount'),
    activeTimePct: pick('activeTimePct'),
    itemLevel: pick('itemLevel'),
    deaths: statsList.reduce((s, x) => s + x.deaths, 0) / statsList.length,
    cpm: pick('cpm'),
    abilities: aggregateMap(statsList.map((s) => s.abilities)),
    casts: aggregateMap(statsList.map((s) => s.casts)),
    buffs: aggregateMap(statsList.map((s) => s.buffs)),
  };
}

function ratioStatus(you, bench) {
  if (you == null || !bench) return 'neutral';
  const r = you / bench;
  return r >= 0.95 ? 'good' : r >= 0.85 ? 'warn' : 'bad';
}

function castStatus(you, bench) {
  if (bench < 0.3) return 'neutral';
  const r = you / bench;
  if (r < 0.75) return 'bad';
  if (r < 0.9) return 'warn';
  if (r > 1.25) return 'over';
  return 'good';
}

function uptimeStatus(you, bench) {
  if (bench < 10) return 'neutral';
  if (you >= bench - 5) return 'good';
  return you >= bench - 15 ? 'warn' : 'bad';
}

function compareMap(mine, bench, statusFn, { minValue = 0 } = {}) {
  const guids = new Set([...Object.keys(bench), ...Object.keys(mine)]);
  const rows = [];
  for (const guid of guids) {
    const b = bench[guid];
    const m = mine[guid];
    const you = m?.value ?? 0;
    const benchValue = b?.value ?? 0;
    if (Math.max(you, benchValue) < minValue) continue;
    rows.push({
      guid: Number(guid),
      name: (b ?? m).name,
      icon: (b ?? m).icon,
      you,
      bench: benchValue,
      presence: b?.presence ?? 0,
      status: statusFn(you, benchValue),
    });
  }
  return rows.sort((a, b) => b.bench - a.bench || b.you - a.you);
}

const fmt = (n, d = 1) => (n == null ? '–' : Number(n).toLocaleString('en-US', { maximumFractionDigits: d, minimumFractionDigits: d }));

export function compare(player, bench, { metric = 'dps' } = {}) {
  const label = metric.toUpperCase();
  const summary = [
    { key: 'amount', label, you: player.amount, bench: bench.amount, unit: '', decimals: 0, status: ratioStatus(player.amount, bench.amount) },
    { key: 'activeTimePct', label: 'Active time', you: player.activeTimePct, bench: bench.activeTimePct, unit: '%', decimals: 1, status: ratioStatus(player.activeTimePct, bench.activeTimePct) },
    { key: 'cpm', label: 'Casts per minute', you: player.cpm, bench: bench.cpm, unit: '', decimals: 1, status: ratioStatus(player.cpm, bench.cpm) },
    { key: 'itemLevel', label: 'Item level', you: player.itemLevel, bench: bench.itemLevel, unit: '', decimals: 1, status: player.itemLevel == null || bench.itemLevel == null ? 'neutral' : player.itemLevel >= bench.itemLevel - 3 ? 'good' : 'warn' },
    { key: 'deaths', label: 'Deaths', you: player.deaths, bench: bench.deaths, unit: '', decimals: 1, lowerIsBetter: true, status: player.deaths <= bench.deaths ? 'good' : 'bad' },
  ];

  const casts = compareMap(player.casts, bench.casts, castStatus, { minValue: 0.05 });
  const abilities = compareMap(player.abilities, bench.abilities, () => 'neutral', { minValue: 1 });
  const buffs = compareMap(player.buffs, bench.buffs, uptimeStatus, { minValue: 5 });

  const takeaways = [];
  const add = (severity, text) => takeaways.push({ severity, text });
  const minutes = player.durationMs / 60000;

  if (player.activeTimePct != null && bench.activeTimePct != null && bench.activeTimePct - player.activeTimePct >= 3) {
    add(bench.activeTimePct - player.activeTimePct >= 8 ? 3 : 2,
      `Active time ${fmt(player.activeTimePct)}% vs ${fmt(bench.activeTimePct)}%. Downtime is usually the biggest single loss: keep casting while moving and during transitions.`);
  }
  for (const c of casts) {
    if (c.status === 'bad' && c.bench >= 0.5) {
      const missed = Math.round((c.bench - c.you) * minutes);
      add(c.you === 0 && c.presence >= 0.75 ? 3 : 2, c.you === 0
        ? `You never cast ${c.name}, but ${Math.round(c.presence * 100)}% of top players did (${fmt(c.bench)}/min). Talent or build difference?`
        : `${c.name}: ${fmt(c.you)} casts/min vs ${fmt(c.bench)}/min, roughly ${missed} fewer casts this fight.`);
    }
  }
  for (const b of buffs) {
    if (b.status === 'bad') add(2, `${b.name} uptime ${fmt(b.you, 0)}% vs ${fmt(b.bench, 0)}%.`);
  }
  if (player.deaths > 0 && bench.deaths < 0.5) add(3, `You died ${player.deaths}×. The top players almost never do, and a death costs all remaining damage.`);
  if (player.itemLevel != null && bench.itemLevel != null && bench.itemLevel - player.itemLevel >= 5) {
    add(1, `Item level ${fmt(player.itemLevel)} vs ${fmt(bench.itemLevel)}: part of the gap is gear, not play.`);
  }
  takeaways.sort((a, b) => b.severity - a.severity);

  return { summary, casts, abilities, buffs, takeaways: takeaways.slice(0, 8) };
}
