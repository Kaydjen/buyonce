// The send of one trip, shared by the manual path (/send) and the cron. All I/O goes
// through `api`, so the exactly-once logic is tested with a fake (test/process.test.js).
//
// api.now() -> Date
// api.claim(trip, leaseUntil) -> claimed doc | null   (null: someone else won)
// api.listDocs(collectionPath) -> docs
// api.getDocs(paths) -> Map path -> doc (missing ones absent)
// api.commit(ops) -> void (throws when a precondition fails)
// api.push({token, title, body, data}) -> 'ok' | 'unregistered'
// api.newId() -> string

import { LEASE_MS, askOps, boughtText, finalizeOps, neededText, recipientIds } from './logic.js';

export async function processTrip(api, tripDoc) {
  const groupPath = tripDoc.path.split('/trips/')[0];

  if (tripDoc.fields.pushedAt) {
    // Done earlier; only the lease is left behind.
    if (tripDoc.fields.autoSendAt) {
      await api.commit([{ path: tripDoc.path, remove: ['autoSendAt'], must: { updateTime: tripDoc.updateTime } }]);
    }
    return { status: 'already' };
  }

  const now = api.now();
  const claimed = await api.claim(tripDoc, new Date(now.getTime() + LEASE_MS));
  if (!claimed) return { status: 'lost' };

  const marks = Object.keys(claimed.fields.marks ?? {});
  const members = await api.listDocs(`${groupPath}/members`);
  const recipients = recipientIds(members, claimed.fields.userId);
  const products = await api.getDocs(marks.map((id) => `${groupPath}/products/${id}`));
  const byId = new Map(marks.filter((id) => products.has(`${groupPath}/products/${id}`)).map((id) => [id, products.get(`${groupPath}/products/${id}`)]));

  let productIds = [...byId.keys()];
  if (!claimed.fields.finalizedAt) {
    const plan = finalizeOps({ trip: claimed, groupPath, products: byId, recipients, now, noticeId: api.newId });
    await api.commit(plan.ops);
    productIds = plan.productIds;
  }

  let pushed = 0;
  if (productIds.length > 0 && recipients.length > 0) {
    const profile = (await api.getDocs([`profiles/${claimed.fields.userId}`])).get(`profiles/${claimed.fields.userId}`);
    const text = boughtText(
      profile?.fields.displayName || 'Someone',
      productIds.map((id) => byId.get(id).fields.name ?? ''),
    );
    const users = await api.getDocs(recipients.map((u) => `users/${u}`));
    for (const uid of recipients) {
      const user = users.get(`users/${uid}`);
      const token = user?.fields.fcmToken;
      if (!token) continue;
      const result = await api.push({ token, ...text, data: { kind: 'bought', groupId: groupPath.split('/')[1] } });
      if (result === 'ok') pushed += 1;
      else if (result === 'unregistered') {
        // Only if the token is still the one that failed (updateTime precondition).
        await api.commit([{ path: user.path, remove: ['fcmToken'], must: { updateTime: user.updateTime } }]).catch(() => {});
      }
    }
  }

  await api.commit([{ path: tripDoc.path, set: { pushedAt: api.now() }, remove: ['autoSendAt'] }]);
  return { status: 'sent', pushed };
}

export const ASK_FRESH_MS = 2 * 60 * 1000;

/// "Ask" of one member. `member` is the caller's member document (read with the caller's
/// token, which proves membership). The client sends ids; each must be a product the
/// caller planned. Exactly one notice set per `askedAt`.
export async function processAsk(api, member, productIds) {
  const groupPath = member.path.split('/members/')[0];
  const userId = member.id;
  const askedAt = member.fields.askedAt;
  const now = api.now();
  if (!(askedAt instanceof Date) || now - askedAt > ASK_FRESH_MS) return { status: 'stale' };
  if (member.fields.askPushedFor instanceof Date && +member.fields.askPushedFor === +askedAt) {
    return { status: 'already' };
  }

  const paths = productIds.map((id) => `${groupPath}/products/${id}`);
  const found = await api.getDocs(paths);
  const mine = productIds
    .map((id) => found.get(`${groupPath}/products/${id}`))
    .filter((p) => p && p.fields.planned === true && p.fields.plannedBy === userId);
  const members = await api.listDocs(`${groupPath}/members`);
  const recipients = recipientIds(members, userId);

  const plan = askOps({
    member, groupPath, userId, productIds: mine.map((p) => p.id), recipients, now, noticeId: api.newId,
  });
  await api.commit(plan); // fails when another call answered this ask first
  if (mine.length === 0 || recipients.length === 0) return { status: 'sent', pushed: 0 };

  const profile = (await api.getDocs([`profiles/${userId}`])).get(`profiles/${userId}`);
  const text = neededText(profile?.fields.displayName || 'Someone', mine.map((p) => p.fields.name ?? ''));
  const users = await api.getDocs(recipients.map((u) => `users/${u}`));
  let pushed = 0;
  for (const uid of recipients) {
    const user = users.get(`users/${uid}`);
    if (!user?.fields.fcmToken) continue;
    const result = await api.push({
      token: user.fields.fcmToken,
      ...text,
      data: { kind: 'needed', groupId: groupPath.split('/')[1] },
    });
    if (result === 'ok') pushed += 1;
    else if (result === 'unregistered') {
      await api.commit([{ path: user.path, remove: ['fcmToken'], must: { updateTime: user.updateTime } }]).catch(() => {});
    }
  }
  return { status: 'sent', pushed };
}
