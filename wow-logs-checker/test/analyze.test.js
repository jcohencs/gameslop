import test from 'node:test';
import assert from 'node:assert/strict';
import { aggregateBenchmark, compare, extractStats, findRanking, median, percentileTarget, pickSample, specFromIcon } from '../lib/analyze.js';

test('percentileTarget finds the 99th percentile slot', () => {
  assert.deepEqual(percentileTarget(48213, 99), { position: 483, page: 5, index: 82 });
  assert.deepEqual(percentileTarget(50, 99), { position: 1, page: 1, index: 0 });
  assert.deepEqual(percentileTarget(1000, 95), { position: 50, page: 1, index: 49 });
});

test('pickSample centers on the index and clamps at the edges', () => {
  const list = Array.from({ length: 100 }, (_, i) => i);
  assert.deepEqual(pickSample(list, 50, 4), [48, 49, 50, 51]);
  assert.deepEqual(pickSample(list, 0, 4), [0, 1, 2, 3]);
  assert.deepEqual(pickSample(list, 99, 4), [96, 97, 98, 99]);
  assert.deepEqual(pickSample([1, 2], 0, 6), [1, 2]);
});

test('median and specFromIcon', () => {
  assert.equal(median([3, 1, 2]), 2);
  assert.equal(median([4, 1, 2, 3]), 2.5);
  assert.equal(median([null, undefined]), null);
  assert.deepEqual(specFromIcon('DeathKnight-Blood'), { className: 'DeathKnight', specName: 'Blood' });
});

test('findRanking reads role, spec and parse from report rankings', () => {
  const rankings = { data: [{ roles: {
    tanks: { characters: [] },
    healers: { characters: [{ name: 'Healy', class: 'Priest', spec: 'Holy', amount: 500000, rankPercent: 80 }] },
    dps: { characters: [{ name: 'Zap', class: 'Mage', spec: 'Frost', amount: 1000000, rankPercent: 42 }] },
  } }] };
  assert.deepEqual(findRanking(rankings, 'Healy'), { role: 'healers', className: 'Priest', specName: 'Holy', amount: 500000, rankPercent: 80, bracketPercent: null });
  assert.equal(findRanking(rankings, 'Nobody'), null);
  assert.equal(findRanking([], 'Zap'), null);
});

const tables = (castTotal) => ({
  fight: { startTime: 1000, endTime: 1000 + 120000 },
  damage: { entries: [{ id: 7, name: 'Zap', total: 120_000_000, activeTime: 108000, itemLevel: 640 }] },
  damageAbilities: { entries: [{ guid: 116, name: 'Frostbolt', abilityIcon: 'a.jpg', total: 90 }, { guid: 30455, name: 'Ice Lance', abilityIcon: 'b.jpg', total: 30 }] },
  casts: { entries: [{ guid: 116, name: 'Frostbolt', total: castTotal }, { guid: 12472, name: 'Icy Veins', total: 1 }] },
  buffs: { totalTime: 120000, auras: [{ guid: 12472, name: 'Icy Veins', totalUptime: 30000 }] },
  deaths: { entries: [{ id: 7, name: 'Zap' }, { id: 8, name: 'Other' }] },
});

test('extractStats derives per-minute and percentage stats', () => {
  const s = extractStats(tables(30), { sourceId: 7, name: 'Zap' });
  assert.equal(s.durationMs, 120000);
  assert.equal(s.amount, 1_000_000);
  assert.equal(s.activeTimePct, 90);
  assert.equal(s.itemLevel, 640);
  assert.equal(s.deaths, 1);
  assert.equal(s.casts[116].value, 15);
  assert.equal(s.cpm, 15.5);
  assert.equal(s.abilities[116].value, 75);
  assert.equal(s.buffs[12472].value, 25);
});

test('compare flags under-casting and produces takeaways', () => {
  const bench = aggregateBenchmark([40, 42, 44].map((n) => extractStats(tables(n), { sourceId: 7, name: 'Zap' })));
  assert.equal(bench.size, 3);
  assert.equal(bench.casts[116].value, 21);
  const me = extractStats(tables(20), { sourceId: 7, name: 'Zap' });
  const result = compare(me, bench);
  const frostbolt = result.casts.find((c) => c.guid === 116);
  assert.equal(frostbolt.status, 'bad');
  assert.ok(result.takeaways.some((t) => t.text.startsWith('Frostbolt')));
  assert.equal(result.summary.find((s) => s.key === 'deaths').status, 'good');
});

test('aggregate drops abilities fewer than half the sample use', () => {
  const a = { abilities: {}, buffs: {}, casts: { 1: { guid: 1, name: 'Rare', value: 3 } }, deaths: 0 };
  const b = { abilities: {}, buffs: {}, casts: {}, deaths: 0 };
  const agg = aggregateBenchmark([a, b, b]);
  assert.equal(agg.casts[1], undefined);
  const agg2 = aggregateBenchmark([a, a, b]);
  assert.equal(agg2.casts[1].value, 3);
  assert.equal(Math.round(agg2.casts[1].presence * 100), 67);
});
