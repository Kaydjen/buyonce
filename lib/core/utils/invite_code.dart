import 'dart:math';

const inviteCodeLength = 8;

/// Eight characters without the look-alikes 0, O, 1, I; the Firestore rules accept
/// `[A-Z0-9]{8}`.
String newInviteCode([Random? random]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < inviteCodeLength; i++)
      alphabet.codeUnitAt(r.nextInt(alphabet.length)),
  ]);
}
