import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/amount.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/receipt_reading.dart';
import '../../../domain/models/receipt_review.dart';
import '../list/list_view_model.dart';

/// The review of one scanned receipt: null while there is none. The state is the
/// immutable [ReceiptReview]; this class only starts it from the list screen's data and
/// forwards the user's choices. Nothing is written until "Mark N" (step 68.4), so
/// [discard] (back) leaves no trace.
class ReceiptReviewViewModel extends Notifier<ReceiptReview?> {
  @override
  ReceiptReview? build() => null;

  /// Starts a review of [reading] against the products and marks the list shows now.
  /// Returns false when the list is not loaded.
  bool begin(ReceiptReading reading) {
    final list = ref.read(listViewModelProvider).value;
    if (list == null) return false;
    state = ReceiptReview.from(
      reading,
      products: list.products,
      myMarkIds: list.myMarkIds,
      partnerMarkIds: list.partnerMarkIds,
    );
    return true;
  }

  void toggle(String id) => _change((r) => r.toggle(id));

  void setAllNew(bool checked) => _change((r) => r.setAllNew(checked));

  void setAmount(String id, Amount amount) =>
      _change((r) => r.setAmount(id, amount));

  /// A new product's name edited in place.
  void rename(String id, String name) => _change((r) => r.rename(id, name));

  /// A row pointed at another product, or at "New product" ([product] null).
  void pick(String id, Product? product) => _change((r) => r.pick(id, product));

  /// Back: the review and the photos' result are dropped.
  void discard() => state = null;

  void _change(ReceiptReview Function(ReceiptReview) change) {
    final current = state;
    if (current != null) state = change(current);
  }
}

final receiptReviewProvider =
    NotifierProvider<ReceiptReviewViewModel, ReceiptReview?>(
      ReceiptReviewViewModel.new,
    );
