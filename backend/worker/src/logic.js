// Pure rules of the send: who gets told, what the text says, what the finalize changes.

export const LEASE_MS = 2 * 60 * 1000;

/// Other members who did not mute the group. `members`: [{id, fields: {muted}}].
export function recipientIds(members, senderId) {
  return members.filter((m) => m.id !== senderId && m.fields.muted !== true).map((m) => m.id);
}

const SHOWN = 3;

const cut = (n) => (n.length > 30 ? `${n.slice(0, 29)}…` : n);

/// The text is built here from the documents; the client only sends ids. Product names are
/// the group's own, cut so one long name cannot fill the screen.
export function boughtText(senderName, productNames) {
  const names = productNames.map(cut);
  const shown = names.slice(0, SHOWN).join(', ');
  const more = names.length - SHOWN;
  return {
    title: senderName,
    body: more > 0 ? `Bought: ${shown} and ${more} more` : `Bought: ${shown}`,
  };
}

/// What finalizing a closed (or due) trip writes, as ops for `opToWrite`.
///   trip: decoded trip doc ({path, updateTime, fields}); updateTime is the claimed one.
///   products: Map productId -> decoded product doc, only those that exist.
///   recipients: user ids. `noticeId()` makes ids. Returns { ops, productIds }.
export function finalizeOps({ trip, groupPath, products, recipients, now, noticeId }) {
  const productIds = Object.keys(trip.fields.marks ?? {}).filter((id) => products.has(id));
  const ops = [
    {
      path: trip.path,
      set: { open: false },
      serverTime: trip.fields.sentAt ? ['finalizedAt'] : ['sentAt', 'finalizedAt'],
      must: { updateTime: trip.updateTime },
    },
  ];
  for (const id of productIds) {
    const p = products.get(id);
    ops.push({
      path: `${groupPath}/products/${id}`,
      ...(p.fields.planned === true
        ? { set: { planned: false }, remove: ['plannedBy', 'plannedAt'] }
        : {}),
      increment: { usage: 1 },
      must: { exists: true },
    });
  }
  if (productIds.length > 0) {
    for (const to of recipients) {
      ops.push({
        path: `${groupPath}/notices/${noticeId()}`,
        set: {
          toUserId: to,
          fromUserId: trip.fields.userId,
          productIds,
          sentAt: now,
          kind: 'bought',
          seen: false,
        },
        must: { exists: false },
      });
    }
  }
  return { ops, productIds };
}

/// "Ask": the products the sender planned and nobody has taken yet.
export function neededText(senderName, productNames) {
  const names = productNames.map(cut);
  const shown = names.slice(0, SHOWN).join(', ');
  const more = names.length - SHOWN;
  return {
    title: senderName,
    body: more > 0 ? `Needs: ${shown} and ${more} more` : `Needs: ${shown}`,
  };
}

/// Ops of an ask: one notice per recipient, and the member document remembers which
/// `askedAt` was answered (the precondition makes a repeated call a no-op).
export function askOps({ member, groupPath, userId, productIds, recipients, now, noticeId }) {
  const ops = [
    {
      path: member.path,
      set: { askPushedFor: member.fields.askedAt },
      must: { updateTime: member.updateTime },
    },
  ];
  for (const to of recipients) {
    ops.push({
      path: `${groupPath}/notices/${noticeId()}`,
      set: { toUserId: to, fromUserId: userId, productIds, sentAt: now, kind: 'needed', seen: false },
      must: { exists: false },
    });
  }
  return ops;
}
