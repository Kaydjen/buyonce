import '../../core/utils/result.dart';
import '../../domain/models/notice.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/product.dart';
import '../../domain/models/trip.dart';

/// A write the server refused or never confirmed. The write itself already showed on
/// the screen (local-first); the streams then show the real data again.
class ListWriteError {
  const ListWriteError(this.error);
  final Object error;
}

/// Storage of products, trips, plans and notices of the groups.
///
/// Local-first contract (the Firestore service follows it too):
/// - a `watch*` stream emits the current value to a new listener, then every change,
///   and a local write shows in it at once, before the server answered;
/// - a write method completes as soon as the write is applied locally. It never waits
///   for the server, so an offline write does not hang; a refusal comes later through
///   [writeErrors] and the streams show the real data again;
/// - a `get*` method answers from the local data (the live listeners keep it fresh),
///   not from a round trip to the server, so an action does not wait before it writes.
///
/// Writes are split by what the security rules tell apart: a document is created with
/// fixed starting values and updated only in some fields. The server alone writes
/// `usage`, the notices and the "finalized" state of a sent trip (a Worker, step 61);
/// until it exists [closeTrip] and [ask] stand in for it on the service side.
abstract class ListService {
  Stream<Result<List<Product>>> watchProducts(String groupId);

  /// Every open trip of the group: one per member who has unsent marks.
  Stream<Result<List<Trip>>> watchOpenTrips(String groupId);

  Stream<Result<List<Plan>>> watchPlans(String groupId);

  Stream<Result<List<Notice>>> watchNotices(String groupId);

  /// Writes that failed after they were shown.
  Stream<ListWriteError> get writeErrors;

  /// False while the service cannot reach the server; true at the start.
  Stream<bool> get online;

  Future<Result<DateTime?>> getAskedAt(String groupId, String userId);

  Future<Result<List<Product>>> getProducts(String groupId);

  /// A new product; `usage` starts at 0 whatever the model says.
  Future<Result<void>> createProduct(Product product);

  /// Name, position and the planned state of an existing product (never `usage`).
  Future<Result<void>> updateProduct(Product product);

  /// Several updates in one write: all of them or none.
  Future<Result<void>> updateProducts(List<Product> products);

  Future<Result<List<Plan>>> getPlans(String groupId);

  /// A new plan; the server stamps `createdAt`.
  Future<Result<void>> createPlan(Plan plan);

  /// Pins or unpins a plan, or refreshes its date (the server stamps `createdAt`).
  Future<Result<void>> updatePlan(Plan plan);

  Future<Result<void>> deletePlan(Plan plan);

  Future<Result<List<Notice>>> getNotices(String groupId);

  /// The recipient dismisses a notice.
  Future<Result<void>> markNoticeSeen(Notice notice);

  /// The open trips plus the [limit] latest sent ones (history, "recent" sort).
  Future<Result<List<Trip>>> getTrips(String groupId, {required int limit});

  Future<Result<List<Trip>>> getOpenTrips(String groupId);

  /// The first mark of a user opens a trip.
  Future<Result<void>> createTrip(Trip trip);

  /// Replaces the marks of the user's open trip.
  Future<Result<void>> updateTripMarks(Trip trip);

  /// Sends the trip: it closes, the planned flags of its products are cleared, and the
  /// server counts the trip in `usage` and tells [notify] (Worker, step 61; the
  /// in-memory service does all of it, the Firestore one only closes the trip and
  /// clears the flags until then).
  Future<Result<void>> closeTrip(Trip trip, {required List<String> notify});

  /// "Ask": remembers when [userId] asked, and tells [notify] that the products are
  /// needed (the notices are the server's, see [closeTrip]).
  Future<Result<void>> ask(
    String groupId,
    String userId,
    List<String> productIds, {
    required List<String> notify,
  });

  /// Removes everything the group owns.
  Future<Result<void>> deleteGroupData(String groupId);

  /// A member left: the open trip and the unread notices of that user go; the sent
  /// trips stay, they are the group's history.
  Future<Result<void>> deleteMemberData(String groupId, String userId);
}
