import test from 'node:test';
import assert from 'node:assert/strict';
import { createChecker } from '../lib/checker.js';
import { createDemoSource } from '../lib/demo.js';

test('demo pipeline: list report and analyze a player end to end', async () => {
  const checker = createChecker(createDemoSource());
  const report = await checker.listReport('DEMOreport1');
  assert.equal(report.fights.length, 3);
  assert.ok(report.fights[0].players.some((p) => p.name === 'Frostyboi' && p.specName === 'Frost'));

  const result = await checker.analyze('DEMOreport1', 3, 1);
  assert.equal(result.player.className, 'Mage');
  assert.equal(result.player.metric, 'dps');
  assert.equal(result.benchmark.percentile, 99);
  assert.equal(result.benchmark.position, 483);
  assert.equal(result.benchmark.size, 6);
  const amount = result.comparison.summary.find((s) => s.key === 'amount');
  assert.ok(amount.you < amount.bench, 'demo player should be below the benchmark');
  assert.ok(result.comparison.takeaways.some((t) => t.text.includes('Ray of Frost')), 'dropped ability is called out');
});

test('healers are compared on HPS', async () => {
  const result = await createChecker(createDemoSource()).analyze('DEMOreport1', 9, 3);
  assert.equal(result.player.role, 'healers');
  assert.equal(result.player.metric, 'hps');
  assert.ok(result.comparison.casts.length > 0);
});

test('wipes without rankings fall back to the actor spec', async () => {
  const result = await createChecker(createDemoSource()).analyze('DEMOreport1', 7, 2);
  assert.equal(result.player.specName, 'Havoc');
  assert.equal(result.player.rankPercent, null);
});

test('bad input errors clearly', async () => {
  const checker = createChecker(createDemoSource());
  await assert.rejects(checker.analyze('DEMOreport1', 999, 1), /isn't a boss encounter/);
  await assert.rejects(checker.analyze('DEMOreport1', 3, 999), /not found/);
});
