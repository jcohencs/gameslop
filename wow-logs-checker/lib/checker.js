// Ties a data source to the analysis: load a report, then compare one player's
// fight against a sample of players at the target percentile for their spec.
import { aggregateBenchmark, compare, extractStats, findRanking, percentileTarget, pickSample, serverName, specFromIcon } from './analyze.js';

export const DIFFICULTY = { 1: 'LFR', 3: 'Normal', 4: 'Heroic', 5: 'Mythic' };

function ttlCache(ttlMs) {
  const map = new Map();
  return async (key, fn) => {
    const hit = map.get(key);
    if (hit && hit.expires > Date.now()) return hit.value;
    const value = fn();
    map.set(key, { value, expires: Date.now() + ttlMs });
    try {
      return await value;
    } catch (err) {
      map.delete(key);
      throw err;
    }
  };
}

export function createChecker(source, { sampleSize = 6, percentile = 99 } = {}) {
  const reportCache = ttlCache(5 * 60_000);
  const benchCache = ttlCache(6 * 60 * 60_000);

  const getReport = (code) => reportCache(code, () => source.getReport(code));

  async function listReport(code) {
    const report = await getReport(code);
    const actors = report.masterData?.actors ?? [];
    return {
      code: report.code ?? code,
      title: report.title,
      zone: report.zone?.name ?? null,
      fights: (report.fights ?? [])
        .filter((f) => f.encounterID)
        .map((f) => ({
          id: f.id,
          encounterId: f.encounterID,
          name: f.name,
          kill: !!f.kill,
          difficulty: DIFFICULTY[f.difficulty] ?? `Difficulty ${f.difficulty}`,
          durationMs: f.endTime - f.startTime,
          fightPercentage: f.fightPercentage ?? null,
          players: (f.friendlyPlayers ?? actors.map((a) => a.id))
            .map((id) => actors.find((a) => a.id === id))
            .filter(Boolean)
            .map((a) => ({ id: a.id, name: a.name, server: a.server, ...specFromIcon(a.icon) })),
        })),
    };
  }

  async function getBenchmark({ encounterId, className, specName, metric, difficulty }) {
    const key = [encounterId, className, specName, metric, difficulty].join('|');
    return benchCache(key, async () => {
      const args = { encounterId, className, specName, metric, difficulty };
      const first = await source.getCharacterRankings({ ...args, page: 1 });
      let rankingsPage = first;
      let target = null;
      if (Number.isFinite(first.count) && first.count > 0) {
        target = percentileTarget(first.count, percentile);
        if (target.page > 1) rankingsPage = await source.getCharacterRankings({ ...args, page: target.page });
      }
      // No total count from the API: fall back to the top of the leaderboard.
      const sampleRankings = pickSample(rankingsPage.rankings ?? [], target?.index ?? 0, sampleSize);
      const refs = sampleRankings.map((r) => ({
        code: r.report?.code,
        fightId: r.report?.fightID,
        name: r.name,
        server: serverName(r.server),
        amount: r.amount,
      }));
      const fights = await source.getBenchmarkFights(refs);
      const role = metric === 'hps' ? 'healers' : 'dps';
      const stats = fights.map((f) => extractStats(f, { sourceId: f.ref.sourceId, name: f.ref.name, role, amount: f.ref.amount }));
      return {
        percentile: target ? percentile : null,
        totalRanked: first.count ?? null,
        position: target?.position ?? null,
        sample: refs.map((r) => ({ ...r, analyzed: fights.some((f) => f.ref.code === r.code && f.ref.name === r.name) })),
        aggregate: aggregateBenchmark(stats),
      };
    });
  }

  async function analyze(code, fightId, sourceId) {
    const report = await getReport(code);
    const fight = report.fights?.find((f) => f.id === fightId);
    if (!fight) throw new Error(`Fight ${fightId} isn't a boss encounter in this report`);
    const actor = report.masterData?.actors?.find((a) => a.id === sourceId);
    if (!actor) throw new Error(`Player ${sourceId} not found in this report`);

    const tables = await source.getPlayerFight(code, fightId, sourceId);
    const ranking = findRanking(tables.rankings, actor.name);
    const iconSpec = specFromIcon(actor.icon);
    const className = ranking?.className ?? iconSpec.className;
    const specName = ranking?.specName ?? iconSpec.specName;
    if (!className || !specName) throw new Error(`Couldn't work out ${actor.name}'s spec from the log`);
    const role = ranking?.role ?? 'dps';
    const metric = role === 'healers' ? 'hps' : 'dps';

    const player = extractStats(tables, { sourceId, name: actor.name, role, amount: ranking?.amount ?? null });
    const benchmark = await getBenchmark({ encounterId: fight.encounterID, className, specName, metric, difficulty: fight.difficulty });
    if (!benchmark.aggregate) throw new Error(`No ranked ${specName} ${className} logs found to compare against for this boss`);

    return {
      player: { name: actor.name, server: actor.server, className, specName, role, metric, rankPercent: ranking?.rankPercent ?? null },
      fight: {
        id: fight.id,
        name: fight.name,
        difficulty: DIFFICULTY[fight.difficulty] ?? String(fight.difficulty),
        kill: !!fight.kill,
        durationMs: player.durationMs,
      },
      benchmark: {
        percentile: benchmark.percentile,
        totalRanked: benchmark.totalRanked,
        position: benchmark.position,
        sample: benchmark.sample,
        size: benchmark.aggregate.size,
        durationMs: benchmark.aggregate.durationMs,
      },
      comparison: compare(player, benchmark.aggregate, { metric }),
    };
  }

  return { listReport, analyze };
}
