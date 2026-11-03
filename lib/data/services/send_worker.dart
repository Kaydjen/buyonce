/// The server part of a send: after the phone has closed a trip, the Worker tells the
/// other members (notices, push) and counts the usage. A failed call is harmless: the
/// trip carries a lease time and the server finishes it by itself a little later.
abstract interface class SendWorker {
  Future<void> finishSend(String groupId, String tripId);

  /// "Notify N": after the phone has stamped its ask, the Worker tells the others which of
  /// [productIds] (its own planned products) are needed.
  Future<void> finishAsk(String groupId, List<String> productIds);
}
