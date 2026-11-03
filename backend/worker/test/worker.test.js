import assert from 'node:assert/strict';
import { test } from 'node:test';

import { decodeDoc, decodeValue, encodeValue, opToWrite } from '../src/firestore.js';
import { boughtText, finalizeOps, recipientIds } from '../src/logic.js';
import { processAsk, processTrip } from '../src/process.js';
import { handleAsk, handleSend } from '../src/index.js';

const BASE = 'projects/p/databases/(default)/documents';

test('values survive an encode and decode round trip', () => {
  const v = { a: 'x', n: 3, d: 1.5, t: new Date('2026-11-03T10:00:00Z'), l: ['q', true], m: { k: false } };
  assert.deepEqual(decodeValue(encodeValue(v)), v);
});

test('opToWrite: mask, deletes, transforms and preconditions', () => {
  const w = opToWrite(
    {
      path: 'groups/g/products/p1',
      set: { planned: false },
      remove: ['plannedBy', 'plannedAt'],
      increment: { usage: 1 },
      serverTime: ['finalizedAt'],
      must: { updateTime: 'T' },
    },
    BASE,
  );
  assert.equal(w.update.name, `${BASE}/groups/g/products/p1`);
  assert.deepEqual(w.update.fields, { planned: { booleanValue: false } });
  assert.deepEqual(w.updateMask.fieldPaths, ['planned', 'plannedBy', 'plannedAt']);
  assert.deepEqual(w.updateTransforms, [
    { fieldPath: 'usage', increment: { integerValue: '1' } },
    { fieldPath: 'finalizedAt', setToServerValue: 'REQUEST_TIME' },
  ]);
  assert.deepEqual(w.currentDocument, { updateTime: 'T' });
  assert.deepEqual(opToWrite({ path: 'a/b', must: { exists: false } }, BASE).currentDocument, { exists: false });
});

test('recipients skip the sender and muted members', () => {
  const members = [
    { id: 'a', fields: { muted: false } },
    { id: 'b', fields: { muted: true } },
    { id: 'c', fields: {} },
  ];
  assert.deepEqual(recipientIds(members, 'a'), ['c']);
});

test('text lists three names and counts the rest', () => {
  assert.deepEqual(boughtText('Anna', ['Milk', 'Bread']), { title: 'Anna', body: 'Bought: Milk, Bread' });
  assert.equal(boughtText('Anna', ['a', 'b', 'c', 'd', 'e']).body, 'Bought: a, b, c and 2 more');
  assert.ok(boughtText('A', ['x'.repeat(80)]).body.length < 50);
});

// ---- processTrip with a fake world ----

const G = 'groups/g';

function world({ marks = ['p1', 'p2'], extra = {} } = {}) {
  const docs = new Map();
  const put = (path, fields) => docs.set(path, { path, id: path.split('/').pop(), updateTime: `t0`, fields });
  put(`${G}/trips/t1`, {
    userId: 'alice',
    open: false,
    sentAt: new Date(),
    marks: Object.fromEntries(marks.map((m) => [m, new Date()])),
    autoSendAt: new Date(),
    ...extra,
  });
  put(`${G}/members/alice`, { muted: false });
  put(`${G}/members/bob`, { muted: false });
  put(`${G}/members/carl`, { muted: true });
  put(`${G}/products/p1`, { name: 'Milk', planned: true, plannedBy: 'bob', usage: 2 });
  put(`${G}/products/p2`, { name: 'Bread', planned: false, usage: 0 });
  put('profiles/alice', { displayName: 'Alice' });
  for (const u of ['bob', 'carl']) put(`users/${u}`, { fcmToken: `token-${u}` });
  let version = 0;
  const log = { commits: [], pushes: [] };
  const api = {
    now: () => new Date('2026-11-03T12:00:00Z'),
    newId: () => `n${(version += 1)}`,
    async claim(trip, until) {
      const d = docs.get(trip.path);
      if (d.updateTime !== trip.updateTime) return null;
      d.updateTime = `t${(version += 1)}`;
      d.fields.autoSendAt = until;
      return { ...d, fields: { ...d.fields } };
    },
    async listDocs(col) {
      return [...docs.values()].filter((d) => d.path.startsWith(`${col}/`));
    },
    async getDocs(paths) {
      return new Map(paths.filter((p) => docs.has(p)).map((p) => [p, docs.get(p)]));
    },
    async commit(ops) {
      log.commits.push(ops);
    },
    async push(m) {
      log.pushes.push(m);
      return m.token === 'token-bob' && world.bobGone ? 'unregistered' : 'ok';
    },
  };
  return { docs, api, log, trip: () => docs.get(`${G}/trips/t1`) };
}

test('send: finalize once, one notice and one push for the other unmuted member', async () => {
  const w = world();
  const r = await processTrip(w.api, w.trip());
  assert.deepEqual(r, { status: 'sent', pushed: 1 });
  const finalize = w.log.commits[0];
  assert.deepEqual(finalize[0].set, { open: false });
  assert.deepEqual(finalize[0].serverTime, ['finalizedAt']); // sentAt already set by the client
  const p1 = finalize.find((o) => o.path.endsWith('products/p1'));
  assert.deepEqual(p1.remove, ['plannedBy', 'plannedAt']);
  assert.deepEqual(p1.increment, { usage: 1 });
  const p2 = finalize.find((o) => o.path.endsWith('products/p2'));
  assert.equal(p2.set, undefined); // not planned: only the counter moves
  const notices = finalize.filter((o) => o.path.includes('/notices/'));
  assert.equal(notices.length, 1);
  assert.equal(notices[0].set.toUserId, 'bob');
  assert.equal(w.log.pushes.length, 1);
  assert.equal(w.log.pushes[0].token, 'token-bob');
  assert.equal(w.log.pushes[0].title, 'Alice');
  assert.equal(w.log.pushes[0].body, 'Bought: Milk, Bread');
  const last = w.log.commits.at(-1)[0];
  assert.deepEqual(last.remove, ['autoSendAt']);
  assert.ok(last.set.pushedAt);
});

test('two runners at once: exactly one sends', async () => {
  const w = world();
  const a = { ...w.trip() };
  const b = { ...w.trip() };
  const results = await Promise.all([processTrip(w.api, a), processTrip(w.api, b)]);
  assert.deepEqual(results.map((r) => r.status).sort(), ['lost', 'sent']);
  assert.equal(w.log.pushes.length, 1);
});

test('an auto-sent open trip also gets sentAt', async () => {
  const w = world({ extra: { open: true, sentAt: undefined } });
  delete w.trip().fields.sentAt;
  await processTrip(w.api, w.trip());
  assert.deepEqual(w.log.commits[0][0].serverTime, ['sentAt', 'finalizedAt']);
});

test('retry after a crash: finalized already, so no second notice, push still goes', async () => {
  const w = world({ extra: { finalizedAt: new Date() } });
  await processTrip(w.api, w.trip());
  assert.equal(w.log.commits.filter((c) => c.some((o) => o.path.includes('/notices/'))).length, 0);
  assert.equal(w.log.pushes.length, 1);
});

test('a pushed trip is not sent again, only the lease is removed', async () => {
  const w = world({ extra: { pushedAt: new Date() } });
  const r = await processTrip(w.api, w.trip());
  assert.equal(r.status, 'already');
  assert.equal(w.log.pushes.length, 0);
  assert.deepEqual(w.log.commits[0][0].remove, ['autoSendAt']);
});

test('an empty trip closes without notices or push', async () => {
  const w = world({ marks: [] });
  const r = await processTrip(w.api, w.trip());
  assert.deepEqual(r, { status: 'sent', pushed: 0 });
  assert.equal(w.log.pushes.length, 0);
  assert.equal(w.log.commits[0].length, 1);
});

test('an unregistered token is removed with a precondition', async () => {
  world.bobGone = true;
  const w = world();
  await processTrip(w.api, w.trip());
  world.bobGone = false;
  const removal = w.log.commits.find((c) => c[0].path === 'users/bob');
  assert.deepEqual(removal[0].remove, ['fcmToken']);
  assert.deepEqual(removal[0].must, { updateTime: 't0' });
});

test('deleted products are skipped', async () => {
  const w = world();
  w.docs.delete(`${G}/products/p2`);
  await processTrip(w.api, w.trip());
  assert.equal(w.log.commits[0].filter((o) => o.path.includes('/products/')).length, 1);
  assert.equal(w.log.pushes[0].body, 'Bought: Milk');
});

// ---- /send authorisation ----

const jwt = (sub) => `h.${btoa(JSON.stringify({ sub })).replace(/=+$/, '')}.s`;
const req = (token, body) =>
  new Request('https://w/send', {
    method: 'POST',
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });

test('/send: no token, bad ids, foreign trip, open trip', async () => {
  const w = world();
  const read = async () => w.trip();
  const ok = { groupId: 'g', tripId: 't1' };
  assert.equal((await handleSend(req(null, ok), {}, w.api, read)).status, 401);
  assert.equal((await handleSend(req(jwt('alice'), { groupId: '../x', tripId: 't' }), {}, w.api, read)).status, 400);
  assert.equal((await handleSend(req(jwt('bob'), ok), {}, w.api, read)).status, 403);
  assert.equal((await handleSend(req(jwt('alice'), ok), {}, w.api, async () => null)).status, 403);
  delete w.trip().fields.sentAt;
  assert.equal((await handleSend(req(jwt('alice'), ok), {}, w.api, read)).status, 409);
  w.trip().fields.sentAt = new Date();
  const done = await handleSend(req(jwt('alice'), ok), {}, w.api, read);
  assert.equal(done.status, 200);
  assert.equal((await done.json()).status, 'sent');
});

// ---- ask ----

function askWorld({ askedAgo = 1000, extra = {} } = {}) {
  const w = world();
  const member = w.docs.get(`${G}/members/alice`);
  member.fields = { muted: false, askedAt: new Date(new Date('2026-11-03T12:00:00Z') - askedAgo), ...extra };
  w.docs.get(`${G}/products/p1`).fields.plannedBy = 'alice';
  w.docs.get(`${G}/products/p2`).fields = { name: 'Bread', planned: true, plannedBy: 'bob' };
  return { ...w, member };
}

test('ask: notices and a push for products the caller planned, not of others', async () => {
  const w = askWorld();
  const r = await processAsk(w.api, w.member, ['p1', 'p2', 'gone']);
  assert.deepEqual(r, { status: 'sent', pushed: 1 });
  const ops = w.log.commits[0];
  assert.deepEqual(ops[0].set, { askPushedFor: w.member.fields.askedAt });
  assert.equal(ops[1].set.kind, 'needed');
  assert.deepEqual(ops[1].set.productIds, ['p1']);
  assert.equal(ops[1].set.toUserId, 'bob');
  assert.equal(w.log.pushes[0].body, 'Needs: Milk');
});

test('ask: an old ask and an answered ask send nothing', async () => {
  const old = askWorld({ askedAgo: 5 * 60 * 1000 });
  assert.equal((await processAsk(old.api, old.member, ['p1'])).status, 'stale');
  const done = askWorld();
  done.member.fields.askPushedFor = done.member.fields.askedAt;
  assert.equal((await processAsk(done.api, done.member, ['p1'])).status, 'already');
  assert.equal(done.log.pushes.length, 0);
});

test('/ask: token, ids and membership are checked', async () => {
  const w = askWorld();
  const read = async () => w.member;
  const ok = { groupId: 'g', productIds: ['p1'] };
  const post = (token, body) => new Request('https://w/ask', { method: 'POST', headers: token ? { authorization: `Bearer ${token}` } : {}, body: JSON.stringify(body) });
  assert.equal((await handleAsk(post(null, ok), {}, w.api, read)).status, 401);
  assert.equal((await handleAsk(post(jwt('alice'), { groupId: 'g', productIds: ['../x'] }), {}, w.api, read)).status, 400);
  assert.equal((await handleAsk(post(jwt('alice'), ok), {}, w.api, async () => null)).status, 403);
  assert.equal((await handleAsk(post(jwt('alice'), ok), {}, w.api, read)).status, 200);
});
