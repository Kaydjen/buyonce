// The Worker against the real Firestore REST semantics (emulator): masks, deletes,
// transforms, preconditions and the claim. Run with `npm test` in backend/.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { decodeDoc } from '../src/firestore.js';
import { processAsk, processTrip } from '../src/process.js';
import { createApi } from '../src/rest.js';

const env = { PROJECT: 'demo-buyonce', FIRESTORE_BASE: 'http://127.0.0.1:8080', EMULATOR_TOKEN: 'owner' };
const pushes = [];
const api = { ...createApi(env), push: async (m) => (pushes.push(m), 'ok') };
const G = 'groups/wk1';

const put = (path, set) => api.commit([{ path, set }]);
const read = async (path) => (await api.getDocs([path])).get(path);

async function seed() {
  await put(`${G}/members/wk-alice`, { muted: false });
  await put(`${G}/members/wk-bob`, { muted: false });
  await put(`${G}/members/wk-carl`, { muted: true });
  await put(`${G}/products/p1`, { name: 'Milk', planned: true, plannedBy: 'wk-bob', plannedAt: new Date(), usage: 2, need: { count: 2, ml: 1500 } });
  await put(`${G}/products/p2`, { name: 'Bread', planned: false, usage: 0 });
  await put('profiles/wk-alice', { displayName: 'Alice' });
  await put('users/wk-bob', { fcmToken: 'tok-wk-bob' });
  await put(`${G}/trips/t1`, {
    userId: 'wk-alice',
    open: false,
    sentAt: new Date(),
    autoSendAt: new Date(Date.now() - 1000),
    marks: {
      p1: { at: new Date(), count: 2, ml: 1500, price: { minor: 3290, cur: 'UAH' }, discount: { minor: 100, cur: 'UAH' } },
      p2: new Date(),
    },
    receipts: [{ store: 'Shop', total: { minor: 3290, cur: 'UAH' } }],
  });
}

test('due trip is found by the collection-group query and sent once', async () => {
  await seed();
  // Runs after the rules tests (sequentially: they clear the emulator) and may find their trips: look at ours.
  const due = (await api.dueTrips(new Date(), 50)).filter((t) => t.path.startsWith(G));
  assert.equal(due.length, 1);

  const results = await Promise.allSettled([processTrip(api, due[0]), processTrip(api, { ...due[0] })]);
  const statuses = results.map((r) => (r.status === 'fulfilled' ? r.value.status : 'error')).sort();
  assert.ok(statuses.includes('sent'), JSON.stringify(results));
  assert.equal(statuses.filter((s) => s === 'sent').length, 1);
  assert.equal(pushes.length, 1);
  assert.equal(pushes[0].token, 'tok-wk-bob');
  assert.match(pushes[0].body, /Milk x2 1\.5 l/); // the mark's amount is in the text

  const p1 = (await read(`${G}/products/p1`)).fields;
  assert.equal(p1.planned, false);
  assert.equal(p1.plannedBy, undefined);
  assert.equal(p1.plannedAt, undefined);
  assert.equal(p1.need, undefined); // sending clears the need with the plan
  assert.equal(p1.usage, 3);
  assert.equal(p1.name, 'Milk'); // the mask left the rest alone
  const p2 = (await read(`${G}/products/p2`)).fields;
  assert.equal(p2.usage, 1);
  assert.equal(p2.planned, false);

  const trip = (await read(`${G}/trips/t1`)).fields;
  assert.ok(trip.finalizedAt instanceof Date);
  assert.ok(trip.pushedAt instanceof Date);
  assert.equal(trip.autoSendAt, undefined);
  assert.equal(trip.open, false);

  const notices = (await api.listDocs(`${G}/notices`)).map((d) => d.fields);
  assert.equal(notices.length, 1);
  assert.equal(notices[0].toUserId, 'wk-bob');
  assert.deepEqual(notices[0].productIds.sort(), ['p1', 'p2']);

  assert.equal((await api.dueTrips(new Date(), 50)).filter((t) => t.path.startsWith(G)).length, 0);
});

test('ask: one notice set per askedAt, the member document keeps the answer', async () => {
  const G2 = 'groups/wk2';
  await put(`${G2}/members/wk-alice`, { muted: false, askedAt: new Date() });
  await put(`${G2}/members/wk-bob`, { muted: false });
  await put(`${G2}/products/p1`, { name: 'Milk', planned: true, plannedBy: 'wk-alice' });
  await put('profiles/wk-alice', { displayName: 'Alice' });
  await put('users/wk-bob', { fcmToken: 'tok-wk-bob' });
  pushes.length = 0;

  const member = await read(`${G2}/members/wk-alice`);
  const first = await processAsk(api, member, ['p1']);
  assert.deepEqual(first, { status: 'sent', pushed: 1 });
  assert.equal(pushes[0].body, 'Needs: Milk');

  // The same stale copy again: the precondition refuses it, nothing is sent twice.
  await assert.rejects(processAsk(api, member, ['p1']));
  const again = await processAsk(api, await read(`${G2}/members/wk-alice`), ['p1']);
  assert.equal(again.status, 'already');
  assert.equal(pushes.length, 1);

  const notices = (await api.listDocs(`${G2}/notices`)).map((d) => d.fields);
  assert.equal(notices.length, 1);
  assert.equal(notices[0].kind, 'needed');
  assert.equal(notices[0].toUserId, 'wk-bob');
});
