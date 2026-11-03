// BuyOnce Worker: finishes the send of a trip (notices, usage, push) for both paths.
//   POST /send {groupId, tripId}  with the caller's Firebase ID token: manual Send.
//   POST /ask {groupId, productIds}: "Notify N" (products the caller still needs).
//   cron (every minute): trips whose `autoSendAt` has passed: auto-send, or the retry of a
//   send that died half way.
// The client sends ids only; every name and text is read from the documents here.

import { processAsk, processTrip } from './process.js';
import { createApi, readAsCaller } from './rest.js';

const ID = /^[A-Za-z0-9_-]{1,64}$/;
const DUE_PER_TICK = 3; // the Free plan allows few subrequests per invocation

/// The payload of the ID token. Not verified here: the Firestore read made with the same
/// token proves it is genuine (rules check the signature), and `sub` is compared after it.
function uidOf(idToken) {
  try {
    const payload = idToken.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(payload)).sub ?? '';
  } catch {
    return '';
  }
}

const reply = (status, body) => Response.json(body, { status });

export async function handleSend(request, env, api = createApi(env), read = readAsCaller) {
  const auth = request.headers.get('authorization') ?? '';
  const idToken = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!idToken) return reply(401, { ok: false, error: 'no token' });
  let body;
  try {
    body = await request.json();
  } catch {
    return reply(400, { ok: false, error: 'bad json' });
  }
  const { groupId, tripId } = body ?? {};
  if (!ID.test(groupId ?? '') || !ID.test(tripId ?? '')) return reply(400, { ok: false, error: 'bad ids' });

  const trip = await read(env, idToken, `groups/${groupId}/trips/${tripId}`);
  const uid = uidOf(idToken);
  if (!trip || !uid || trip.fields.userId !== uid) return reply(403, { ok: false, error: 'not your trip' });
  if (!trip.fields.sentAt) return reply(409, { ok: false, error: 'trip is not closed' });

  const result = await processTrip(api, trip);
  return reply(200, { ok: true, ...result });
}

/// POST /ask {groupId, productIds}: the caller's member document (read as the caller)
/// proves membership and carries the server time of the ask.
export async function handleAsk(request, env, api = createApi(env), read = readAsCaller) {
  const auth = request.headers.get('authorization') ?? '';
  const idToken = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!idToken) return reply(401, { ok: false, error: 'no token' });
  let body;
  try {
    body = await request.json();
  } catch {
    return reply(400, { ok: false, error: 'bad json' });
  }
  const { groupId, productIds } = body ?? {};
  if (
    !ID.test(groupId ?? '') ||
    !Array.isArray(productIds) ||
    productIds.length > 200 ||
    !productIds.every((p) => typeof p === 'string' && ID.test(p))
  ) {
    return reply(400, { ok: false, error: 'bad ids' });
  }
  const uid = uidOf(idToken);
  const member = uid && (await read(env, idToken, `groups/${groupId}/members/${uid}`));
  if (!member) return reply(403, { ok: false, error: 'not a member' });
  const result = await processAsk(api, member, [...new Set(productIds)]);
  return reply(200, { ok: true, ...result });
}

export async function runDue(env, api = createApi(env)) {
  const due = await api.dueTrips(api.now(), DUE_PER_TICK);
  const report = { due: due.length, sent: 0, lost: 0, already: 0, errors: 0 };
  for (const trip of due) {
    try {
      const r = await processTrip(api, trip);
      if (r.status === 'sent') report.sent += 1;
      else if (r.status === 'lost') report.lost += 1;
      else report.already += 1;
    } catch (e) {
      report.errors += 1;
      console.log(`trip ${trip.path} failed: ${e.message}`); // retried after the lease ends
    }
  }
  return report;
}

export default {
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(
      runDue(env)
        .then((r) => r.due > 0 && console.log(JSON.stringify(r)))
        .catch((e) => console.log(`cron failed: ${e.message}`)),
    );
  },
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/send' && request.method === 'POST') {
      try {
        return await handleSend(request, env);
      } catch (e) {
        console.log(`send failed: ${e.message}`);
        return reply(500, { ok: false, error: 'failed' }); // the cron finishes it
      }
    }
    if (url.pathname === '/ask' && request.method === 'POST') {
      try {
        return await handleAsk(request, env);
      } catch (e) {
        console.log(`ask failed: ${e.message}`);
        return reply(500, { ok: false, error: 'failed' });
      }
    }
    return new Response('not found', { status: 404 });
  },
};
