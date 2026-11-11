import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  collectionGroup,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

// alice owns group g1 with bob; carol is a signed-in outsider.
const CODE = 'ABCD2345';
let env;

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-buyonce',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const now = Timestamp.now();
    await setDoc(doc(db, 'groups/g1'), {
      name: 'Home', utcOffsetMin: 60, ownerId: 'alice', personal: false,
      inviteCode: CODE, memberCount: 2, createdAt: now,
    });
    await setDoc(doc(db, 'joinCodes', CODE), { groupId: 'g1' });
    for (const u of ['alice', 'bob']) {
      await setDoc(doc(db, `groups/g1/members/${u}`), { userId: u, joinedAt: now, muted: false });
    }
    await setDoc(doc(db, 'groups/g1/products/milk'), {
      name: 'Milk', position: 1, planned: false, usage: 3,
    });
    await setDoc(doc(db, 'groups/g1/trips/t-alice'), {
      userId: 'alice', startedAt: now, marks: { milk: now }, autoSendAt: now, open: true,
    });
    await setDoc(doc(db, 'groups/g1/trips/t-sent'), {
      userId: 'bob', startedAt: now, marks: {}, sentAt: now, finalizedAt: now, pushedAt: now, open: false,
    });
    await setDoc(doc(db, 'groups/g1/notices/n1'), {
      toUserId: 'bob', fromUserId: 'alice', productIds: ['milk'], sentAt: now, kind: 'bought', seen: false,
    });
    await setDoc(doc(db, 'groups/g1/plans/p1'), { productIds: ['milk'], createdAt: now, pinned: false });
    await setDoc(doc(db, 'users/alice'), { fcmToken: 'tok', updatedAt: now });
    await setDoc(doc(db, 'profiles/alice'), { displayName: 'Alex' });
  });
});

describe('unsigned user', () => {
  it('reads and writes nothing', async () => {
    const db = anon();
    await assertFails(getDoc(doc(db, 'groups/g1')));
    await assertFails(getDoc(doc(db, 'profiles/alice')));
    await assertFails(getDoc(doc(db, 'joinCodes', CODE)));
    await assertFails(setDoc(doc(db, 'users/x'), { fcmToken: 't', updatedAt: serverTimestamp() }));
  });
});

describe('users and profiles', () => {
  it('users/{uid} is private', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'users/alice')));
    await assertFails(getDoc(doc(as('bob'), 'users/alice')));
    await assertFails(setDoc(doc(as('bob'), 'users/alice'), { fcmToken: 'x', updatedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(as('bob'), 'users/bob'), { fcmToken: 'x', updatedAt: serverTimestamp() }));
  });

  it('users/{uid} accepts only a token and server time', async () => {
    const d = doc(as('bob'), 'users/bob');
    await assertFails(setDoc(d, { fcmToken: 'x', updatedAt: serverTimestamp(), admin: true }));
    await assertFails(setDoc(d, { fcmToken: '', updatedAt: serverTimestamp() }));
    await assertFails(setDoc(d, { fcmToken: 'x', updatedAt: Timestamp.fromMillis(0) }));
  });

  it('a profile is readable by get, not by list, and writable only by its user', async () => {
    await assertSucceeds(getDoc(doc(as('carol'), 'profiles/alice')));
    await assertFails(getDocs(collection(as('carol'), 'profiles')));
    await assertFails(setDoc(doc(as('carol'), 'profiles/alice'), { displayName: 'Hacked' }));
    await assertSucceeds(setDoc(doc(as('carol'), 'profiles/carol'), { displayName: 'Mom' }));
    await assertFails(setDoc(doc(as('carol'), 'profiles/carol'), { displayName: 'x'.repeat(41) }));
    await assertFails(setDoc(doc(as('carol'), 'profiles/carol'), { displayName: '' }));
  });
});

describe('group read', () => {
  it('a member reads, a non-member does not', async () => {
    await assertSucceeds(getDoc(doc(as('bob'), 'groups/g1')));
    await assertFails(getDoc(doc(as('carol'), 'groups/g1')));
  });

  it('a non-member reads and writes nothing inside the group', async () => {
    const db = as('carol');
    for (const path of ['members/alice', 'products/milk', 'trips/t-alice', 'plans/p1', 'notices/n1']) {
      await assertFails(getDoc(doc(db, `groups/g1/${path}`)));
    }
    await assertFails(setDoc(doc(db, 'groups/g1/products/x'), {
      name: 'X', position: 2, planned: false, usage: 0,
    }));
    await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { name: 'Hacked' }));
    await assertFails(deleteDoc(doc(db, 'groups/g1/products/milk')));
  });

  it('a user finds own memberships by the collection-group query, nobody else\'s', async () => {
    const mine = query(collectionGroup(as('bob'), 'members'), where('userId', '==', 'bob'));
    const snap = await assertSucceeds(getDocs(mine));
    if (snap.size !== 1) throw new Error(`expected 1 membership, got ${snap.size}`);
    await assertFails(getDocs(query(collectionGroup(as('bob'), 'members'), where('userId', '==', 'alice'))));
    await assertFails(getDocs(collectionGroup(as('bob'), 'members')));
  });
});

describe('create a group', () => {
  const sharedGroup = (over = {}) => ({
    name: 'Work', utcOffsetMin: 120, ownerId: 'carol', personal: false,
    inviteCode: 'ZZZZ9999', memberCount: 1, createdAt: serverTimestamp(), ...over,
  });

  const create = (uid, groupData, { member = true, code = true } = {}) => {
    const db = as(uid);
    const b = writeBatch(db);
    b.set(doc(db, 'groups/g2'), groupData);
    if (member) b.set(doc(db, `groups/g2/members/${uid}`), { userId: uid, joinedAt: serverTimestamp(), muted: false });
    if (code) b.set(doc(db, 'joinCodes/ZZZZ9999'), { groupId: 'g2' });
    return b.commit();
  };

  it('works with the own membership and the join code in one batch', async () => {
    await assertSucceeds(create('carol', sharedGroup()));
  });

  it('fails without the membership, without the code, for another owner, with a count over 1', async () => {
    await assertFails(create('carol', sharedGroup(), { member: false }));
    await assertFails(create('carol', sharedGroup(), { code: false }));
    await assertFails(create('carol', sharedGroup({ ownerId: 'bob' })));
    await assertFails(create('carol', sharedGroup({ memberCount: 5 })));
    await assertFails(create('carol', sharedGroup({ createdAt: Timestamp.fromMillis(0) })));
  });

  it('the code of someone else\'s group cannot be claimed', async () => {
    await assertFails(setDoc(doc(as('carol'), 'joinCodes/OTHER123'), { groupId: 'g1' }));
  });

  it('a personal list has the fixed id, one member, no code', async () => {
    const db = as('carol');
    const group = {
      name: 'Personal', utcOffsetMin: 0, ownerId: 'carol', personal: true,
      memberCount: 1, createdAt: serverTimestamp(),
    };
    const b = writeBatch(db);
    b.set(doc(db, 'groups/personal-carol'), group);
    b.set(doc(db, 'groups/personal-carol/members/carol'), { userId: 'carol', joinedAt: serverTimestamp(), muted: false });
    await assertSucceeds(b.commit());

    const wrong = writeBatch(db);
    wrong.set(doc(db, 'groups/personal-bob'), group);
    wrong.set(doc(db, 'groups/personal-bob/members/carol'), { userId: 'carol', joinedAt: serverTimestamp(), muted: false });
    await assertFails(wrong.commit());
  });

  it('nobody can join a personal list', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'groups/personal-alice'), {
        name: 'Personal', utcOffsetMin: 0, ownerId: 'alice', personal: true,
        memberCount: 1, createdAt: Timestamp.now(),
      });
    });
    const db = as('carol');
    const b = writeBatch(db);
    b.set(doc(db, 'groups/personal-alice/members/carol'), {
      userId: 'carol', joinedAt: serverTimestamp(), muted: false, joinCode: CODE,
    });
    b.update(doc(db, 'groups/personal-alice'), { memberCount: 2 });
    await assertFails(b.commit());
  });
});

describe('join by code', () => {
  const join = (uid, { code = CODE, bump = 3, who = uid } = {}) => {
    const db = as(uid);
    const b = writeBatch(db);
    b.set(doc(db, `groups/g1/members/${who}`), {
      userId: who, joinedAt: serverTimestamp(), muted: false, joinCode: code,
    });
    if (bump !== null) b.update(doc(db, 'groups/g1'), { memberCount: bump });
    return b.commit();
  };

  it('works with the right code and the counter bumped by one', async () => {
    await assertSucceeds(join('carol'));
    await assertSucceeds(getDoc(doc(as('carol'), 'groups/g1/products/milk')));
  });

  it('fails with a wrong code, a missing counter, a wrong counter, or for another user', async () => {
    await assertFails(join('carol', { code: 'WRONG123' }));
    await assertFails(join('carol', { bump: null }));
    await assertFails(join('carol', { bump: 9 }));
    await assertFails(join('carol', { who: 'dave' }));
  });

  it('a code of another group does not open this one', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'joinCodes/OTHER123'), { groupId: 'g9' });
    });
    await assertFails(join('carol', { code: 'OTHER123' }));
  });

  it('a group holds at most 20 members', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'groups/g1'), { memberCount: 20 });
    });
    await assertFails(join('carol', { bump: 21 }));
  });

  it('the member counter cannot be changed on its own', async () => {
    await assertFails(updateDoc(doc(as('carol'), 'groups/g1'), { memberCount: 3 }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1'), { memberCount: 1 }));
  });

  it('codes cannot be listed, only fetched', async () => {
    await assertSucceeds(getDoc(doc(as('carol'), 'joinCodes', CODE)));
    await assertFails(getDocs(collection(as('carol'), 'joinCodes')));
  });
});

describe('leave, remove, ownership, delete', () => {
  it('a member leaves and lowers the counter', async () => {
    const db = as('bob');
    const b = writeBatch(db);
    b.delete(doc(db, 'groups/g1/members/bob'));
    b.update(doc(db, 'groups/g1'), { memberCount: 1 });
    await assertSucceeds(b.commit());
  });

  it('the counter cannot be lowered without leaving', async () => {
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1'), { memberCount: 1 }));
  });

  it('the owner removes a member, a plain member cannot remove another', async () => {
    await assertSucceeds(deleteDoc(doc(as('alice'), 'groups/g1/members/bob')));
    await assertFails(deleteDoc(doc(as('bob'), 'groups/g1/members/alice')));
  });

  it('only the owner changes the group settings', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), 'groups/g1'), { name: 'Our home', utcOffsetMin: 120 }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1'), { name: 'Mine now' }));
    await assertFails(updateDoc(doc(as('alice'), 'groups/g1'), { inviteCode: 'NEWCODE22' }));
    await assertFails(updateDoc(doc(as('alice'), 'groups/g1'), { personal: true }));
  });

  it('ownership passes only to an existing member, only by the owner', async () => {
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1'), { ownerId: 'bob' }));
    await assertFails(updateDoc(doc(as('alice'), 'groups/g1'), { ownerId: 'carol' }));
    await assertSucceeds(updateDoc(doc(as('alice'), 'groups/g1'), { ownerId: 'bob' }));
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1'), { name: 'Bob\'s now' }));
  });

  it('the owner deletes the group, the code and the data; others cannot', async () => {
    await assertFails(deleteDoc(doc(as('bob'), 'groups/g1')));
    await assertFails(deleteDoc(doc(as('bob'), 'joinCodes', CODE)));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'groups/g1/trips/t-sent')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'joinCodes', CODE)));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'groups/g1')));
  });
});

describe('the exact sequences of the app (step 59.2)', () => {
  it('join: the joiner cannot read the group, so the counter goes up by increment(1)', async () => {
    const db = as('carol');
    await assertFails(getDoc(doc(db, 'groups/g1')));
    await assertFails(getDoc(doc(db, 'groups/g1/members/carol')));
    const b = writeBatch(db);
    b.set(doc(db, 'groups/g1/members/carol'), {
      userId: 'carol', joinedAt: serverTimestamp(), muted: false, joinCode: CODE,
    });
    b.update(doc(db, 'groups/g1'), { memberCount: increment(1) });
    await assertSucceeds(b.commit());
    await assertSucceeds(getDoc(doc(db, 'groups/g1')));
  });

  it('join as a transaction-like pair is refused for a member who is in already', async () => {
    const db = as('bob');
    const b = writeBatch(db);
    b.set(doc(db, 'groups/g1/members/bob'), {
      userId: 'bob', joinedAt: serverTimestamp(), muted: false, joinCode: CODE,
    });
    b.update(doc(db, 'groups/g1'), { memberCount: increment(1) });
    await assertFails(b.commit());
  });

  it('join of a full group is refused with increment(1)', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'groups/g1'), { memberCount: 20 });
    });
    const db = as('carol');
    const b = writeBatch(db);
    b.set(doc(db, 'groups/g1/members/carol'), {
      userId: 'carol', joinedAt: serverTimestamp(), muted: false, joinCode: CODE,
    });
    b.update(doc(db, 'groups/g1'), { memberCount: increment(1) });
    await assertFails(b.commit());
  });

  it('a member leaves with increment(-1)', async () => {
    const db = as('bob');
    const b = writeBatch(db);
    b.delete(doc(db, 'groups/g1/members/bob'));
    b.update(doc(db, 'groups/g1'), { memberCount: increment(-1) });
    await assertSucceeds(b.commit());
  });

  it('the owner leaves: ownership to bob, own member deleted, counter down, one batch', async () => {
    const db = as('alice');
    const b = writeBatch(db);
    b.update(doc(db, 'groups/g1'), { ownerId: 'bob', memberCount: increment(-1) });
    b.delete(doc(db, 'groups/g1/members/alice'));
    await assertSucceeds(b.commit());
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1'), { name: 'Bobs now' }));
  });

  it('the owner removes a member and lowers the counter in one batch', async () => {
    const db = as('alice');
    const b = writeBatch(db);
    b.update(doc(db, 'groups/g1'), { memberCount: increment(-1) });
    b.delete(doc(db, 'groups/g1/members/bob'));
    await assertSucceeds(b.commit());
  });

  it('the owner deletes members, the code and the group in one batch; a member cannot', async () => {
    const mine = as('bob');
    const denied = writeBatch(mine);
    denied.delete(doc(mine, 'groups/g1/members/alice'));
    denied.delete(doc(mine, 'groups/g1'));
    await assertFails(denied.commit());

    const db = as('alice');
    const b = writeBatch(db);
    b.delete(doc(db, 'groups/g1/members/alice'));
    b.delete(doc(db, 'groups/g1/members/bob'));
    b.delete(doc(db, 'joinCodes', CODE));
    b.delete(doc(db, 'groups/g1'));
    await assertSucceeds(b.commit());
  });

  it('the last member of a personal list deletes it with its member', async () => {
    const db = as('carol');
    const make = writeBatch(db);
    make.set(doc(db, 'groups/personal-carol'), {
      name: 'Personal', utcOffsetMin: 0, ownerId: 'carol', personal: true,
      memberCount: 1, createdAt: serverTimestamp(),
    });
    make.set(doc(db, 'groups/personal-carol/members/carol'), {
      userId: 'carol', joinedAt: serverTimestamp(), muted: false,
    });
    await assertSucceeds(make.commit());
    const b = writeBatch(db);
    b.delete(doc(db, 'groups/personal-carol/members/carol'));
    b.delete(doc(db, 'groups/personal-carol'));
    await assertSucceeds(b.commit());
  });

  it('rename and mute are single writes', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), 'groups/g1'), { name: 'Our home' }));
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { muted: true }));
  });
});

describe('member settings', () => {
  it('a member changes only own mute and asked time', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { muted: true }));
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { askedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/members/alice'), { muted: true }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { userId: 'alice' }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { joinedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { askedAt: Timestamp.fromMillis(0) }));
  });

  it('a member keeps working with a Worker field askPushedFor but cannot write it', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'groups/g1/members/bob'), { askPushedFor: Timestamp.fromMillis(1) });
    });
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { askedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { muted: true }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { askPushedFor: Timestamp.fromMillis(2) }));
  });

  it('members see each other', async () => {
    await assertSucceeds(getDoc(doc(as('bob'), 'groups/g1/members/alice')));
  });
});

describe('products', () => {
  const newProduct = (over = {}) => ({
    name: 'Bread', position: 2, planned: false, usage: 0, ...over,
  });

  it('a member adds, renames, moves and plans a product', async () => {
    const db = as('bob');
    await assertSucceeds(setDoc(doc(db, 'groups/g1/products/bread'), newProduct()));
    await assertSucceeds(setDoc(doc(db, 'groups/g1/products/eggs'), newProduct({
      name: 'Eggs', planned: true, plannedBy: 'bob', plannedAt: serverTimestamp(),
    })));
    await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), { name: 'Milk 1l', position: 0.5 }));
    await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
      planned: true, plannedBy: 'bob', plannedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), { position: 7 }));
    await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
      planned: false, plannedBy: deleteField(), plannedAt: deleteField(),
    }));
  });

  it('plannedBy cannot be forged and the usage counter is the Worker\'s', async () => {
    const db = as('bob');
    await assertFails(setDoc(doc(db, 'groups/g1/products/x'), newProduct({
      planned: true, plannedBy: 'alice', plannedAt: serverTimestamp(),
    })));
    await assertFails(setDoc(doc(db, 'groups/g1/products/x'), newProduct({ usage: 5 })));
    await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { usage: 99 }));
    await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), {
      planned: true, plannedBy: 'alice', plannedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { name: '' }));
  });

  // The amount wanted (step 66): `need`, only while planned, whole numbers in range.
  describe('the need', () => {
    const plan = { planned: true, plannedBy: 'bob', plannedAt: serverTimestamp() };

    it('is set with or after planning, changed, and cleared with un-planning', async () => {
      const db = as('bob');
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
        ...plan, need: { count: 2, ml: 1500 },
      }));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), { need: { count: 3 } }));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), { need: deleteField() }));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), { need: { g: 500 } }));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
        planned: false, plannedBy: deleteField(), plannedAt: deleteField(), need: deleteField(),
      }));
    });

    it('the exact write of the app on an already planned product', async () => {
      const db = as('bob');
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), plan));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
        name: 'Milk', position: 1, planned: true, need: { count: 2, ml: 500 },
      }));
    });

    it('is refused on a product that is not planned', async () => {
      const db = as('bob');
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { need: { count: 2 } }));
    });

    it('is refused when un-planning leaves it behind', async () => {
      const db = as('bob');
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), { ...plan, need: { count: 2 } }));
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), {
        planned: false, plannedBy: deleteField(), plannedAt: deleteField(),
      }));
    });

    it('must be a map of whole numbers in range with known keys', async () => {
      const db = as('bob');
      for (const need of [
        { count: 0 }, { count: 100 }, { count: 1.5 }, { g: 0 }, { g: 100000 },
        { ml: -1 }, { ml: 'x' }, { price: 3 }, 5, 'two', [1],
      ]) {
        await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { ...plan, need }));
      }
    });

    it('a stranger cannot set it', async () => {
      await assertFails(updateDoc(doc(as('carol'), 'groups/g1/products/milk'), { ...plan, need: { count: 2 } }));
    });
  });

  // The archive: a deleted product keeps its document, with the flag and the server time.
  describe('the archive', () => {
    const del = (db, id = 'milk') => updateDoc(doc(db, `groups/g1/products/${id}`), {
      deleted: true, deletedAt: serverTimestamp(),
    });

    it('a member deletes a product and brings it back', async () => {
      const db = as('bob');
      await assertSucceeds(del(db));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
        deleted: deleteField(), deletedAt: deleteField(),
      }));
    });

    it('a needed product is deleted and un-planned in one write', async () => {
      const db = as('bob');
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
        planned: true, plannedBy: 'bob', plannedAt: serverTimestamp(),
      }));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
        deleted: true, deletedAt: serverTimestamp(),
        planned: false, plannedBy: deleteField(), plannedAt: deleteField(),
      }));
    });

    it('an archived product is renamed and restored under the new name', async () => {
      const db = as('bob');
      await assertSucceeds(del(db));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), { name: 'Milk 1l' }));
      await assertSucceeds(updateDoc(doc(db, 'groups/g1/products/milk'), {
        name: 'Milk 2l', deleted: deleteField(), deletedAt: deleteField(), position: -1,
      }));
    });

    it('the time cannot be forged or left out, and false is not stored', async () => {
      const db = as('bob');
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { deleted: true }));
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), {
        deleted: true, deletedAt: Timestamp.fromMillis(0),
      }));
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { deleted: false }));
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { deletedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), {
        deleted: 'yes', deletedAt: serverTimestamp(),
      }));
    });

    it('the deleted time cannot be changed while the product stays deleted', async () => {
      const db = as('bob');
      await assertSucceeds(del(db));
      await assertFails(updateDoc(doc(db, 'groups/g1/products/milk'), { deletedAt: serverTimestamp() }));
    });

    it('a product is never created already deleted; a stranger cannot delete', async () => {
      await assertFails(setDoc(doc(as('bob'), 'groups/g1/products/x'), {
        name: 'X', position: 3, planned: false, usage: 0, deleted: true, deletedAt: serverTimestamp(),
      }));
      await assertFails(del(as('mallory')));
    });
  });
});

describe('trips', () => {
  it('a member starts only own trip, with server time and no worker fields', async () => {
    const db = as('bob');
    const trip = { userId: 'bob', startedAt: serverTimestamp(), marks: { milk: Timestamp.now() }, open: true };
    await assertSucceeds(setDoc(doc(db, 'groups/g1/trips/t-bob'), trip));
    await assertFails(setDoc(doc(db, 'groups/g1/trips/t2'), { ...trip, userId: 'alice' }));
    await assertFails(setDoc(doc(db, 'groups/g1/trips/t2'), { ...trip, startedAt: Timestamp.fromMillis(0) }));
    await assertFails(setDoc(doc(db, 'groups/g1/trips/t2'), { ...trip, pushedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db, 'groups/g1/trips/t2'), { ...trip, sentAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db, 'groups/g1/trips/t2'), { ...trip, open: false }));
    const { open, ...withoutOpen } = trip;
    await assertFails(setDoc(doc(db, 'groups/g1/trips/t2'), withoutOpen));
  });

  it('the owner of an open trip changes marks and the auto-send time', async () => {
    const d = doc(as('alice'), 'groups/g1/trips/t-alice');
    await assertSucceeds(updateDoc(d, { 'marks.bread': Timestamp.now() }));
    await assertSucceeds(updateDoc(d, { 'marks.milk': deleteField() }));
    await assertSucceeds(updateDoc(d, { autoSendAt: Timestamp.fromMillis(Date.now() + 3600_000) }));
  });

  it('nobody else writes a member\'s trip', async () => {
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/trips/t-alice'), { 'marks.bread': Timestamp.now() }));
    await assertFails(updateDoc(doc(as('carol'), 'groups/g1/trips/t-alice'), { 'marks.bread': Timestamp.now() }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/trips/t-alice'), { sentAt: serverTimestamp() }));
  });

  it('the owner closes the trip once with server time and cannot touch the Worker fields', async () => {
    const d = doc(as('alice'), 'groups/g1/trips/t-alice');
    await assertFails(updateDoc(d, { pushedAt: serverTimestamp() }));
    await assertFails(updateDoc(d, { finalizedAt: serverTimestamp() }));
    await assertFails(updateDoc(d, { userId: 'bob' }));
    await assertFails(updateDoc(d, { sentAt: Timestamp.fromMillis(0) }));
    await assertFails(updateDoc(d, { sentAt: serverTimestamp() }));
    await assertFails(updateDoc(d, { open: false }));
    await assertSucceeds(updateDoc(d, { sentAt: serverTimestamp(), open: false, autoSendAt: Timestamp.fromMillis(Date.now() + 120_000) }));
  });

  it('a sent trip is history: no client edits it or deletes it', async () => {
    const d = doc(as('bob'), 'groups/g1/trips/t-sent');
    await assertFails(updateDoc(d, { 'marks.milk': Timestamp.now() }));
    await assertFails(updateDoc(d, { pushedAt: deleteField() }));
    await assertFails(deleteDoc(d));
  });

  it('an open trip is deleted by its owner or the group owner', async () => {
    await assertFails(deleteDoc(doc(as('bob'), 'groups/g1/trips/t-alice')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'groups/g1/trips/t-alice')));
  });

  it('members read trips, the cron query is not for clients', async () => {
    await assertSucceeds(getDoc(doc(as('bob'), 'groups/g1/trips/t-alice')));
    await assertFails(getDocs(query(collectionGroup(as('bob'), 'trips'), where('autoSendAt', '<=', Timestamp.now()))));
  });
});

describe('trips as the app uses them (step 60)', () => {
  it('members list the open trips of the group with open == true', async () => {
    const q = query(collection(as('bob'), 'groups/g1/trips'), where('open', '==', true));
    const snap = await assertSucceeds(getDocs(q));
    assert.deepEqual(snap.docs.map((d) => d.id), ['t-alice']);
  });

  it('members read the latest sent trips ordered by sentAt', async () => {
    const q = query(collection(as('bob'), 'groups/g1/trips'), orderBy('sentAt', 'desc'), limit(5));
    const snap = await assertSucceeds(getDocs(q));
    assert.deepEqual(snap.docs.map((d) => d.id), ['t-sent']);
  });

  it('send as one batch: the trip closes and the planned flags of its products clear', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'groups/g1/products/milk'), {
        planned: true, plannedBy: 'bob', plannedAt: Timestamp.now(),
      });
    });
    const db = as('alice');
    const b = writeBatch(db);
    b.update(doc(db, 'groups/g1/trips/t-alice'), { sentAt: serverTimestamp(), open: false });
    b.update(doc(db, 'groups/g1/products/milk'), {
      planned: false, plannedBy: deleteField(), plannedAt: deleteField(),
    });
    await assertSucceeds(b.commit());
  });

  it('a member lists only own notices, nobody lists the notices of others', async () => {
    const own = query(collection(as('bob'), 'groups/g1/notices'), where('toUserId', '==', 'bob'));
    await assertSucceeds(getDocs(own));
    await assertFails(getDocs(collection(as('bob'), 'groups/g1/notices')));
    await assertFails(getDocs(query(collection(as('alice'), 'groups/g1/notices'), where('toUserId', '==', 'bob'))));
  });

  it('asking stamps the own member document with server time', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1/members/bob'), { askedAt: serverTimestamp() }));
  });

  it('a plan is pinned without touching its date, and refreshed with server time', async () => {
    const d = doc(as('bob'), 'groups/g1/plans/p1');
    await assertSucceeds(updateDoc(d, { pinned: true }));
    await assertSucceeds(updateDoc(d, { pinned: false, createdAt: serverTimestamp() }));
  });

  it('the owner empties the group: products, trips, plans', async () => {
    const db = as('alice');
    const b = writeBatch(db);
    b.delete(doc(db, 'groups/g1/products/milk'));
    b.delete(doc(db, 'groups/g1/trips/t-alice'));
    b.delete(doc(db, 'groups/g1/trips/t-sent'));
    b.delete(doc(db, 'groups/g1/plans/p1'));
    await assertSucceeds(b.commit());
  });

  it('a leaving member removes the own notices and the own open trip first', async () => {
    const db = as('bob');
    await assertSucceeds(deleteDoc(doc(db, 'groups/g1/notices/n1')));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'groups/g1/trips/t-bob'), {
        userId: 'bob', startedAt: Timestamp.now(), marks: {}, open: true,
      });
    });
    await assertSucceeds(deleteDoc(doc(db, 'groups/g1/trips/t-bob')));
  });
});

describe('plans', () => {
  it('a member saves a plan, pins it and stamps it again', async () => {
    const db = as('bob');
    await assertSucceeds(setDoc(doc(db, 'groups/g1/plans/p2'), {
      productIds: ['milk'], createdAt: serverTimestamp(), pinned: false,
    }));
    await assertSucceeds(updateDoc(doc(db, 'groups/g1/plans/p1'), { pinned: true }));
    await assertSucceeds(updateDoc(doc(db, 'groups/g1/plans/p1'), { createdAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(db, 'groups/g1/plans/p1')));
    await assertFails(updateDoc(doc(db, 'groups/g1/plans/p1'), { productIds: [] }));
  });
});

describe('notices', () => {
  it('clients cannot create notices', async () => {
    await assertFails(setDoc(doc(as('alice'), 'groups/g1/notices/n2'), {
      toUserId: 'bob', fromUserId: 'alice', productIds: [], sentAt: serverTimestamp(), kind: 'bought', seen: false,
    }));
  });

  it('only the recipient reads, marks seen and deletes', async () => {
    await assertSucceeds(getDoc(doc(as('bob'), 'groups/g1/notices/n1')));
    await assertFails(getDoc(doc(as('alice'), 'groups/g1/notices/n1')));
    await assertSucceeds(updateDoc(doc(as('bob'), 'groups/g1/notices/n1'), { seen: true }));
    await assertFails(updateDoc(doc(as('bob'), 'groups/g1/notices/n1'), { toUserId: 'alice' }));
    await assertFails(updateDoc(doc(as('alice'), 'groups/g1/notices/n1'), { seen: true }));
    await assertSucceeds(deleteDoc(doc(as('bob'), 'groups/g1/notices/n1')));
  });
});
