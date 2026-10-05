// Data access against the Warcraft Logs GraphQL API. Returns raw-ish API shapes;
// all interpretation lives in analyze.js so the demo source can share it.
import { unwrap } from './wcl.js';

const CODE_RE = /^[a-zA-Z0-9]{8,32}$/;

export function assertReportCode(code) {
  if (!CODE_RE.test(code ?? '')) throw new Error(`"${code}" doesn't look like a Warcraft Logs report code`);
  return code;
}

function int(n, label) {
  const v = Number(n);
  if (!Number.isInteger(v)) throw new Error(`Invalid ${label}: ${n}`);
  return v;
}

// Every table we need to describe one player in one fight.
function fightTables(fightId, sourceId) {
  const f = `fightIDs: [${int(fightId, 'fight id')}]`;
  const s = `sourceID: ${int(sourceId, 'source id')}`;
  return `
    fights(${f}) { id encounterID name kill difficulty startTime endTime size }
    damage: table(${f}, dataType: DamageDone)
    healing: table(${f}, dataType: Healing)
    damageAbilities: table(${f}, dataType: DamageDone, ${s})
    healingAbilities: table(${f}, dataType: Healing, ${s})
    casts: table(${f}, dataType: Casts, ${s})
    buffs: table(${f}, dataType: Buffs, ${s})
    deaths: table(${f}, dataType: Deaths)`;
}

function normalizeFightTables(r) {
  return {
    fight: r.fights?.[0] ?? null,
    damage: unwrap(r.damage),
    healing: unwrap(r.healing),
    damageAbilities: unwrap(r.damageAbilities),
    healingAbilities: unwrap(r.healingAbilities),
    casts: unwrap(r.casts),
    buffs: unwrap(r.buffs),
    deaths: unwrap(r.deaths),
  };
}

export function createWclSource(client) {
  async function getReport(code) {
    assertReportCode(code);
    const data = await client.query(
      `query($code: String!) { reportData { report(code: $code) {
        code title startTime endTime
        zone { id name }
        fights(killType: Encounters) {
          id encounterID name kill difficulty startTime endTime fightPercentage size friendlyPlayers
        }
        masterData { actors(type: "Player") { id name server subType icon } }
      } } }`,
      { code },
    );
    const report = data.reportData?.report;
    if (!report) throw new Error(`Report ${code} not found (is it private?)`);
    return report;
  }

  async function getPlayerFight(code, fightId, sourceId) {
    assertReportCode(code);
    const data = await client.query(
      `query($code: String!) { reportData { report(code: $code) {
        rankings(fightIDs: [${int(fightId, 'fight id')}])
        ${fightTables(fightId, sourceId)}
      } } }`,
      { code },
    );
    const r = data.reportData.report;
    return { ...normalizeFightTables(r), rankings: unwrap(r.rankings) };
  }

  async function getCharacterRankings({ encounterId, className, specName, metric, difficulty, page = 1 }) {
    const data = await client.query(
      `query($id: Int!, $cls: String!, $spec: String!, $metric: CharacterRankingMetricType, $diff: Int, $page: Int) {
        worldData { encounter(id: $id) {
          name
          characterRankings(className: $cls, specName: $spec, metric: $metric, difficulty: $diff, page: $page)
        } }
      }`,
      { id: encounterId, cls: className, spec: specName, metric, diff: difficulty, page },
    );
    return unwrap(data.worldData?.encounter?.characterRankings) ?? { rankings: [] };
  }

  // refs: [{ code, fightId, name }]. Two batched queries: actor lookup, then tables.
  async function getBenchmarkFights(refs) {
    const valid = refs.filter((r) => CODE_RE.test(r.code ?? ''));
    if (!valid.length) return [];
    const codes = [...new Set(valid.map((r) => r.code))];
    const actorsData = await client.query(
      `query { reportData {
        ${codes.map((c, i) => `r${i}: report(code: "${c}") { masterData { actors(type: "Player") { id name server } } }`).join('\n')}
      } }`,
    );
    const actorsByCode = Object.fromEntries(codes.map((c, i) => [c, actorsData.reportData[`r${i}`]?.masterData?.actors ?? []]));

    const located = valid
      .map((ref) => {
        const actor = actorsByCode[ref.code].find((a) => a.name === ref.name && (!ref.server || !a.server || a.server === ref.server))
          ?? actorsByCode[ref.code].find((a) => a.name === ref.name);
        return actor ? { ...ref, sourceId: actor.id } : null;
      })
      .filter(Boolean);
    if (!located.length) return [];

    const tablesData = await client.query(
      `query { reportData {
        ${located.map((ref, i) => `b${i}: report(code: "${ref.code}") { ${fightTables(ref.fightId, ref.sourceId)} }`).join('\n')}
      } }`,
    );
    return located
      .map((ref, i) => {
        const r = tablesData.reportData[`b${i}`];
        return r ? { ref, ...normalizeFightTables(r) } : null;
      })
      .filter(Boolean);
  }

  return { getReport, getPlayerFight, getCharacterRankings, getBenchmarkFights };
}
