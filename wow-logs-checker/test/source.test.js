import test from 'node:test';
import assert from 'node:assert/strict';
import { createWclSource, assertReportCode } from '../lib/source.js';
import { createWclClient } from '../lib/wcl.js';

test('assertReportCode rejects junk that could break the GraphQL query', () => {
  assert.equal(assertReportCode('AbCd1234XyZ'), 'AbCd1234XyZ');
  assert.throws(() => assertReportCode('abc") { evil }'));
  assert.throws(() => assertReportCode(undefined));
});

test('client authenticates once and unwraps GraphQL errors', async () => {
  const calls = [];
  const fetchImpl = async (url, opts) => {
    calls.push({ url, opts });
    if (url.endsWith('/oauth/token')) return { ok: true, json: async () => ({ access_token: 'tok', expires_in: 3600 }) };
    const body = JSON.parse(opts.body);
    if (body.query.includes('bad')) return { ok: true, status: 200, json: async () => ({ errors: [{ message: 'nope' }] }) };
    return { ok: true, status: 200, json: async () => ({ data: { ok: 1 } }) };
  };
  const client = createWclClient({ clientId: 'id', clientSecret: 'secret', fetchImpl });
  assert.deepEqual(await client.query('{ good }'), { ok: 1 });
  assert.deepEqual(await client.query('{ good }'), { ok: 1 });
  await assert.rejects(client.query('{ bad }'), /nope/);
  assert.equal(calls.filter((c) => c.url.endsWith('/oauth/token')).length, 1);
  assert.equal(calls[0].opts.headers.Authorization, `Basic ${Buffer.from('id:secret').toString('base64')}`);
  assert.equal(calls[1].opts.headers.Authorization, 'Bearer tok');
});

test('getBenchmarkFights batches actor lookup and tables with aliases', async () => {
  const queries = [];
  const client = {
    async query(q) {
      queries.push(q);
      if (queries.length === 1) {
        return { reportData: {
          r0: { masterData: { actors: [{ id: 4, name: 'Alpha', server: 'Area 52' }, { id: 9, name: 'Beta', server: 'Illidan' }] } },
          r1: { masterData: { actors: [] } },
        } };
      }
      return { reportData: {
        b0: { fights: [{ id: 2, startTime: 0, endTime: 60000 }], damage: { data: { entries: [] } }, casts: { data: { entries: [{ guid: 1, total: 5 }] } } },
        b1: { fights: [{ id: 5, startTime: 0, endTime: 60000 }], damage: { data: { entries: [] } } },
      } };
    },
  };
  const out = await createWclSource(client).getBenchmarkFights([
    { code: 'AAAAAAAA1', fightId: 2, name: 'Alpha', server: 'Area 52' },
    { code: 'AAAAAAAA1', fightId: 5, name: 'Beta' },
    { code: 'BBBBBBBB2', fightId: 1, name: 'Missing' },
    { code: 'bad code!', fightId: 1, name: 'Skipped' },
  ]);
  assert.equal(queries.length, 2);
  assert.match(queries[0], /r0: report\(code: "AAAAAAAA1"\)/);
  assert.match(queries[1], /b0: report\(code: "AAAAAAAA1"\)[\s\S]*fightIDs: \[2\][\s\S]*sourceID: 4/);
  assert.match(queries[1], /b1: report[\s\S]*sourceID: 9/);
  assert.equal(out.length, 2);
  assert.equal(out[0].ref.sourceId, 4);
  assert.deepEqual(out[0].casts, { entries: [{ guid: 1, total: 5 }] });
});
