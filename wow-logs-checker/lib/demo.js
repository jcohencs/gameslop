// Offline demo source. Generates deterministic fake data in the same shapes
// the Warcraft Logs API returns, so the whole pipeline runs without API keys.

const SPECS = {
  'Mage-Frost': {
    role: 'dps', amount: 1_150_000, activeTime: 0.985,
    abilities: [
      [116, 'Frostbolt', 'spell_frost_frostbolt02.jpg', 17, 22],
      [30455, 'Ice Lance', 'spell_frost_frostblast.jpg', 13, 20],
      [44614, 'Flurry', 'ability_warlock_burningembersblue.jpg', 4.2, 9],
      [84714, 'Frozen Orb', 'spell_frost_frozenorb.jpg', 1.1, 11],
      [190356, 'Blizzard', 'spell_frost_icestorm.jpg', 1.6, 7],
      [153595, 'Comet Storm', 'spell_mage_cometstorm.jpg', 1.9, 10],
      [199786, 'Glacial Spike', 'ability_mage_glacialspike.jpg', 2.3, 15],
      [205021, 'Ray of Frost', 'ability_mage_rayoffrost.jpg', 0.9, 6],
      [12472, 'Icy Veins', 'spell_frost_coldhearted.jpg', 0.45, 0],
      [382440, 'Shifting Power', 'ability_ardenweald_mage.jpg', 0.65, 0],
    ],
    buffs: [
      [1459, 'Arcane Intellect', 'spell_holy_magicalsentry.jpg', 100],
      [12472, 'Icy Veins', 'spell_frost_coldhearted.jpg', 42],
      [44544, 'Fingers of Frost', 'ability_mage_wintersgrasp.jpg', 38],
      [190446, 'Brain Freeze', 'ability_mage_brainfreeze.jpg', 21],
      [2825, 'Bloodlust', 'spell_nature_bloodlust.jpg', 14],
      [10060, 'Power Infusion', 'spell_holy_powerinfusion.jpg', 12],
    ],
  },
  'DemonHunter-Havoc': {
    role: 'dps', amount: 1_210_000, activeTime: 0.97,
    abilities: [
      [162243, "Demon's Bite", 'inv_weapon_glave_01.jpg', 9, 12],
      [162794, 'Chaos Strike', 'ability_demonhunter_chaosstrike.jpg', 14, 26],
      [188499, 'Blade Dance', 'ability_demonhunter_bladedance.jpg', 5.5, 18],
      [198013, 'Eye Beam', 'ability_demonhunter_eyebeam.jpg', 1.4, 16],
      [258920, 'Immolation Aura', 'ability_demonhunter_immolation.jpg', 2.1, 9],
      [258860, 'Essence Break', 'spell_shadow_ritualofsacrifice.jpg', 1.4, 8],
      [370965, 'The Hunt', 'ability_ardenweald_demonhunter.jpg', 0.55, 6],
      [191427, 'Metamorphosis', 'ability_demonhunter_metamorphasisdps.jpg', 0.45, 0],
      [185123, 'Throw Glaive', 'ability_demonhunter_throwglaive.jpg', 3.1, 5],
    ],
    buffs: [
      [162264, 'Metamorphosis', 'ability_demonhunter_metamorphasisdps.jpg', 31],
      [208628, 'Momentum', 'ability_foundryraid_demolition.jpg', 46],
      [258920, 'Immolation Aura', 'ability_demonhunter_immolation.jpg', 52],
      [2825, 'Bloodlust', 'spell_nature_bloodlust.jpg', 14],
    ],
  },
  'Priest-Holy': {
    role: 'healers', amount: 640_000, activeTime: 0.93,
    abilities: [
      [2050, 'Holy Word: Serenity', 'spell_holy_persuitofjustice.jpg', 1.6, 14],
      [34861, 'Holy Word: Sanctify', 'spell_holy_divineprovidence.jpg', 1.9, 17],
      [33076, 'Prayer of Mending', 'spell_holy_prayerofmendingtga.jpg', 3.4, 18],
      [596, 'Prayer of Healing', 'spell_holy_prayerofhealing02.jpg', 4.5, 19],
      [204883, 'Circle of Healing', 'spell_holy_circleofrenewal.jpg', 3.6, 13],
      [2061, 'Flash Heal', 'spell_holy_flashheal.jpg', 5.5, 8],
      [120517, 'Halo', 'ability_priest_halo.jpg', 1.0, 7],
      [64843, 'Divine Hymn', 'spell_holy_divinehymn.jpg', 0.33, 4],
    ],
    buffs: [
      [200183, 'Apotheosis', 'ability_priest_ascension.jpg', 13],
      [114255, 'Surge of Light', 'spell_holy_surgeoflight.jpg', 18],
      [2825, 'Bloodlust', 'spell_nature_bloodlust.jpg', 14],
    ],
  },
};
const GENERIC = { role: 'dps', amount: 1_000_000, activeTime: 0.96, abilities: [[1, 'Main Ability', 'inv_misc_questionmark.jpg', 20, 60], [2, 'Cooldown', 'inv_misc_questionmark.jpg', 1, 40]], buffs: [] };

const PLAYERS = [
  { id: 1, name: 'Frostyboi', icon: 'Mage-Frost', skill: { amount: 0.78, cast: 0.85, uptime: 0.8, active: 0.9, drop: [205021] } },
  { id: 2, name: 'Glaivelord', icon: 'DemonHunter-Havoc', skill: { amount: 0.92, cast: 0.95, uptime: 0.95, active: 0.98 } },
  { id: 3, name: 'Holyhandgrenade', icon: 'Priest-Holy', skill: { amount: 0.84, cast: 0.9, uptime: 0.85, active: 0.95 } },
  { id: 4, name: 'Tankenstein', icon: 'DeathKnight-Blood', skill: { amount: 0.9, cast: 1, uptime: 1, active: 1 } },
  { id: 5, name: 'Moonbeamz', icon: 'Druid-Balance', skill: { amount: 0.88, cast: 1, uptime: 1, active: 1 } },
];

const FIGHTS = [
  { id: 3, encounterID: 3009, name: 'Vexie and the Geargrinders', kill: true, difficulty: 5, dur: 312_000 },
  { id: 7, encounterID: 3010, name: 'Cauldron of Carnage', kill: false, difficulty: 5, dur: 160_000, fightPercentage: 41.3 },
  { id: 9, encounterID: 3010, name: 'Cauldron of Carnage', kill: true, difficulty: 5, dur: 298_000 },
];

function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32);
}

function specOf(icon) {
  return SPECS[icon] ?? GENERIC;
}

// Build the per-player tables one fight would produce.
function playerTables(spec, skill, durationMs, seed) {
  const r = rng(seed);
  const jitter = (amt) => 1 + (r() - 0.5) * amt;
  const minutes = durationMs / 60000;
  const amount = spec.amount * skill.amount * jitter(0.06);
  const total = Math.round(amount * (durationMs / 1000));
  const weights = spec.abilities.map(([guid, , , , w]) => (skill.drop?.includes(guid) ? 0 : w * jitter(0.3)));
  const weightSum = weights.reduce((a, b) => a + b, 0);
  return {
    amount,
    total,
    activeTime: Math.min(durationMs, Math.round(durationMs * spec.activeTime * skill.active * jitter(0.02))),
    abilities: spec.abilities
      .map(([guid, name, abilityIcon], i) => ({ guid, name, type: 1, abilityIcon, total: Math.round((weights[i] / weightSum) * total) }))
      .filter((e) => e.total > 0),
    casts: spec.abilities
      .map(([guid, name, abilityIcon, cpm]) => ({ guid, name, type: 1, abilityIcon, total: skill.drop?.includes(guid) ? 0 : Math.round(cpm * skill.cast * jitter(0.15) * minutes) }))
      .filter((e) => e.total > 0),
    auras: spec.buffs.map(([guid, name, abilityIcon, up]) => {
      const uptime = up >= 100 ? 100 : up * (guid === 2825 || guid === 10060 ? 1 : skill.uptime) * jitter(0.15);
      return { guid, name, type: 2, abilityIcon, totalUptime: Math.round((Math.min(100, uptime) / 100) * durationMs), totalUses: 1 };
    }),
  };
}

function fightResponse(fight, players, sourceId, seedBase) {
  const meta = { totalTime: fight.dur };
  const generated = players.map((p) => ({ p, spec: specOf(p.icon), t: playerTables(specOf(p.icon), p.skill, fight.dur, seedBase + p.id) }));
  const entry = ({ p, t }) => ({ name: p.name, id: p.id, guid: p.id, type: p.icon.split('-')[0], icon: p.icon, itemLevel: p.ilvl ?? 639.5, total: t.total, activeTime: t.activeTime });
  const me = generated.find((g) => g.p.id === sourceId);
  const dead = players.filter((p) => p.died).map((p) => ({ name: p.name, id: p.id, guid: p.id, type: p.icon.split('-')[0], icon: p.icon, timestamp: fight.dur - 30_000 }));
  return {
    generated,
    tables: {
      fight: { id: fight.id, encounterID: fight.encounterID, name: fight.name, kill: fight.kill, difficulty: fight.difficulty, startTime: 0, endTime: fight.dur, size: 20 },
      damage: { ...meta, entries: generated.filter((g) => g.spec.role !== 'healers').map(entry) },
      healing: { ...meta, entries: generated.filter((g) => g.spec.role === 'healers').map(entry) },
      damageAbilities: { ...meta, entries: me && me.spec.role !== 'healers' ? me.t.abilities : [] },
      healingAbilities: { ...meta, entries: me && me.spec.role === 'healers' ? me.t.abilities : [] },
      casts: { ...meta, entries: me?.t.casts ?? [] },
      buffs: { ...meta, auras: me?.t.auras ?? [] },
      deaths: { entries: dead },
    },
  };
}

const BENCH_COUNT = 48_213;
const benchSkill = (i) => ({ amount: 1 - i * 0.00004, cast: 1, uptime: 1, active: 1 });

export function createDemoSource() {
  const tick = () => new Promise((resolve) => setTimeout(resolve, 150));

  return {
    async getReport(code) {
      await tick();
      return {
        code,
        title: 'Demo raid night',
        zone: { id: 42, name: 'Liberation of Undermine' },
        fights: FIGHTS.map((f) => ({ ...f, startTime: 0, endTime: f.dur, size: 20, friendlyPlayers: PLAYERS.map((p) => p.id) })),
        masterData: { actors: PLAYERS.map((p) => ({ id: p.id, name: p.name, server: 'Illidan', subType: p.icon.split('-')[0], icon: p.icon })) },
      };
    },

    async getPlayerFight(code, fightId, sourceId) {
      await tick();
      const fight = FIGHTS.find((f) => f.id === fightId);
      const players = PLAYERS.map((p) => ({ ...p, died: p.id === 1 && fight.id === 9 }));
      const { generated, tables } = fightResponse(fight, players, sourceId, fight.id * 100);
      const character = ({ p, t }) => {
        const [cls, spec] = p.icon.split('-');
        return { name: p.name, class: cls, spec, amount: t.amount, rankPercent: Math.round(Math.min(99, p.skill.amount ** 6 * 100)), server: { name: 'Illidan' } };
      };
      const role = (r) => generated.filter((g) => (r === 'tanks' ? g.p.icon === 'DeathKnight-Blood' : r === 'healers' ? g.spec.role === 'healers' : g.spec.role !== 'healers' && g.p.icon !== 'DeathKnight-Blood')).map(character);
      const rankings = fight.kill ? { data: [{ fightID: fight.id, roles: { tanks: { characters: role('tanks') }, healers: { characters: role('healers') }, dps: { characters: role('dps') } } }] } : { data: [] };
      return { ...tables, rankings };
    },

    async getCharacterRankings({ encounterId, className, specName, page = 1 }) {
      await tick();
      const spec = specOf(`${className}-${specName}`);
      const start = (page - 1) * 100;
      return {
        page,
        hasMorePages: start + 100 < BENCH_COUNT,
        count: BENCH_COUNT,
        rankings: Array.from({ length: 100 }, (_, k) => {
          const i = start + k;
          return {
            name: `Top${specName}${i + 1}`,
            class: className,
            spec: specName,
            amount: spec.amount * benchSkill(i).amount * 1.04,
            server: { name: 'Area 52', region: 'US' },
            report: { code: `DEMObench${encounterId}x${i}`, fightID: 1 },
          };
        }),
      };
    },

    async getBenchmarkFights(refs) {
      await tick();
      return refs.map((ref) => {
        const [, enc, i] = ref.code.match(/^DEMObench(\d+)x(\d+)$/);
        const spec = ref.name.replace(/^Top/, '').replace(/\d+$/, '');
        const icon = Object.keys(SPECS).find((k) => k.endsWith(`-${spec}`)) ?? 'Generic-Generic';
        const fight = { id: 1, encounterID: Number(enc), name: 'Benchmark', kill: true, difficulty: 5, dur: 280_000 + (Number(i) % 7) * 6000 };
        const player = { id: 1, name: ref.name, icon, skill: benchSkill(Number(i)), ilvl: 642 };
        return { ref: { ...ref, sourceId: 1 }, ...fightResponse(fight, [player], 1, Number(i) * 31 + Number(enc)).tables };
      });
    },
  };
}
