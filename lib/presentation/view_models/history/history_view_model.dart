import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../domain/models/purchase.dart';
import '../groups/groups_view_model.dart';

/// The purchases of the shown group, read again each time the screen opens.
class HistoryViewModel extends AsyncNotifier<List<Purchase>> {
  @override
  Future<List<Purchase>> build() async =>
      switch (await ref.watch(listRepositoryProvider).getHistory()) {
        Ok(:final value) => value,
        Failure(:final error) => throw error,
      };
}

final historyViewModelProvider =
    AsyncNotifierProvider.autoDispose<HistoryViewModel, List<Purchase>>(
      HistoryViewModel.new,
    );
