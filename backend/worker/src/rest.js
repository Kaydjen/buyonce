// The `api` of process.js on the real services: Firestore REST as the service account,
// FCM v1. `base` is replaceable so the tests can point it at the Firestore emulator.

import { decodeDoc, encodeFields, opToWrite } from './firestore.js';
import { accessToken } from './google.js';

export function createApi(env, fetchFn = fetch) {
  const project = env.PROJECT;
  const base = env.FIRESTORE_BASE ?? 'https://firestore.googleapis.com';
  const documents = `projects/${project}/databases/(default)/documents`;
  const url = `${base}/v1/${documents}`;

  const headers = async () => ({
    authorization: `Bearer ${await accessToken(env)}`,
    'content-type': 'application/json',
  });

  const call = async (method, target, body) => {
    const res = await fetchFn(target, { method, headers: await headers(), body: body && JSON.stringify(body) });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      const e = new Error(`firestore ${res.status}: ${json.error?.status ?? 'unknown'}`);
      e.status = res.status;
      throw e;
    }
    return json;
  };

  return {
    now: () => new Date(),
    newId: () => crypto.randomUUID().replace(/-/g, '').slice(0, 20),

    /// Moves `autoSendAt` forward only if nobody changed the document since `trip.updateTime`
    /// (one winner among concurrent runners). Returns the trip as it is after the claim.
    async claim(trip, leaseUntil) {
      const write = opToWrite(
        { path: trip.path, set: { autoSendAt: leaseUntil }, must: { updateTime: trip.updateTime } },
        documents,
      );
      const res = await fetchFn(`${url}:commit`, {
        method: 'POST',
        headers: await headers(),
        body: JSON.stringify({ writes: [write] }),
      });
      if (res.status === 400 || res.status === 404 || res.status === 409) return null; // lost the race
      if (!res.ok) throw new Error(`claim ${res.status}`);
      const done = await res.json();
      return {
        ...trip,
        updateTime: done.writeResults[0].updateTime,
        fields: { ...trip.fields, autoSendAt: leaseUntil },
      };
    },

    async listDocs(collectionPath) {
      const json = await call('GET', `${url}/${collectionPath}?pageSize=50`);
      return (json.documents ?? []).map(decodeDoc);
    },

    async getDocs(paths) {
      const found = new Map();
      if (paths.length === 0) return found;
      const rows = await call('POST', `${url}:batchGet`, {
        documents: paths.map((p) => `${documents}/${p}`),
      });
      for (const row of rows) if (row.found) {
        const doc = decodeDoc(row.found);
        found.set(doc.path, doc);
      }
      return found;
    },

    async commit(ops) {
      await call('POST', `${url}:commit`, { writes: ops.map((op) => opToWrite(op, `${documents}`)) });
    },

    async dueTrips(now, limit) {
      const rows = await call('POST', `${url}:runQuery`, {
        structuredQuery: {
          from: [{ collectionId: 'trips', allDescendants: true }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'autoSendAt' },
              op: 'LESS_THAN_OR_EQUAL',
              value: { timestampValue: now.toISOString() },
            },
          },
          limit,
        },
      });
      return rows.filter((r) => r.document).map((r) => decodeDoc(r.document));
    },

    async push({ token, title, body, data }) {
      const res = await fetchFn(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
        method: 'POST',
        headers: await headers(),
        body: JSON.stringify({
          message: { token, notification: { title, body }, data, android: { priority: 'HIGH' } },
        }),
      });
      if (res.ok) return 'ok';
      const json = await res.json().catch(() => ({}));
      const codes = (json.error?.details ?? []).map((d) => d.errorCode);
      if (res.status === 404 || codes.includes('UNREGISTERED')) return 'unregistered';
      throw new Error(`fcm ${res.status}: ${json.error?.status ?? 'unknown'}`);
    },
  };
}

/// Reads one document with the CALLER's ID token: the rules decide whether it may be read.
export async function readAsCaller(env, idToken, path, fetchFn = fetch) {
  const base = env.FIRESTORE_BASE ?? 'https://firestore.googleapis.com';
  const res = await fetchFn(`${base}/v1/projects/${env.PROJECT}/databases/(default)/documents/${path}`, {
    headers: { authorization: `Bearer ${idToken}` },
  });
  if (!res.ok) return null;
  return decodeDoc(await res.json());
}
