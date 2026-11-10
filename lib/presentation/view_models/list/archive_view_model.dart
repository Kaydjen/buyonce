import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../domain/models/product.dart';
import '../groups/groups_view_model.dart';

/// The deleted products of the shown group, the latest deleted first. The list screen
/// watches it, so the Plan menu knows whether there is an "Archive" to open.
final archivedProductsProvider = StreamProvider.autoDispose<List<Product>>((
  ref,
) {
  final repo = ref.watch(listRepositoryProvider);
  return repo.watchArchive().map(
    (result) => switch (result) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    },
  );
});
