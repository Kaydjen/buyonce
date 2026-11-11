import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/receipt_alias_repository.dart';
import '../../../data/repositories/receipt_parsing_repository.dart';
import '../../../data/services/photo_service.dart';
import '../../../domain/models/gemini_outcome.dart';
import '../../../domain/models/gemini_task.dart';
import '../groups/groups_view_model.dart';
import '../list/list_state.dart';
import '../list/list_view_model.dart';
import '../settings/gemini_models_view_model.dart';
import 'receipt_review_view_model.dart';

class ReceiptScanState {
  const ReceiptScanState({
    this.photos = 0,
    this.busy = false,
    this.problem,
    this.reviewReady = false,
  });

  /// Photos of the receipt taken so far (kept in memory only).
  final int photos;

  /// A photo is being read.
  final bool busy;

  /// Why the last reading gave nothing; the screen shows it once and calls
  /// [ReceiptScanViewModel.problemShown].
  final GeminiOutcome? problem;

  /// The reading succeeded and [receiptReviewProvider] holds the review.
  final bool reviewReady;

  bool get canAddPhoto => !busy && photos < ReceiptParsingRepository.maxPhotos;
}

/// "Scan a receipt" in Shop: the camera (up to [ReceiptParsingRepository.maxPhotos]
/// shots of one receipt), Gemini, then the review. The photos live in memory only and
/// are dropped on [reset] (when the review is closed); nothing is stored anywhere.
class ReceiptScanViewModel extends Notifier<ReceiptScanState> {
  /// Long side of a receipt photo: small print needs more than an item photo.
  static const photoSide = 2048.0;
  static const photoQuality = 85;

  final List<Uint8List> _photos = [];

  @override
  ReceiptScanState build() => const ReceiptScanState();

  /// Opens the camera and keeps the shot. False when no shot was added (the camera was
  /// closed, failed, or the limit is reached).
  Future<bool> addPhoto() async {
    if (!state.canAddPhoto) return false;
    // The camera takes seconds: the connection to Google is opened meanwhile.
    unawaited(ref.read(receiptParsingRepositoryProvider).warmUp());
    final taken = await ref
        .read(photoServiceProvider)
        .takePhoto(maxSide: photoSide, quality: photoQuality);
    if (!ref.mounted) return false;
    switch (taken) {
      case Ok(:final value) when value != null:
        _photos.add(value);
        state = ReceiptScanState(photos: _photos.length);
        return true;
      case Ok():
        return false; // the camera was closed
      case Failure():
        state = ReceiptScanState(
          photos: _photos.length,
          problem: const GeminiFailed(),
        );
        return false;
    }
  }

  /// Reads the photos taken so far and opens the review. [language] is the English name
  /// of the app language; [fallbackCurrency] an ISO code for a receipt that shows none.
  /// On success the review opens and the photos stay for it; on a problem they stay for
  /// a retry.
  Future<void> read({
    required String language,
    required String fallbackCurrency,
  }) async {
    if (state.busy || _photos.isEmpty) return;
    final list = ref.read(listViewModelProvider).value;
    if (list == null) return;
    state = ReceiptScanState(photos: _photos.length, busy: true);
    final models = await ref.read(
      geminiModelsProvider(GeminiTask.receipts).future,
    );
    final aliases = await _aliasNames(list);
    if (!ref.mounted) return;
    final result = await ref
        .read(receiptParsingRepositoryProvider)
        .read(
          List.of(_photos),
          language: language,
          models: models,
          knownNames: namesByImportance(list),
          fallbackCurrency: fallbackCurrency,
          aliases: aliases,
        );
    if (!ref.mounted) return;
    switch (result) {
      case ParsedReceipt(:final reading):
        final started = ref.read(receiptReviewProvider.notifier).begin(reading);
        if (started) {
          // The photos stay in memory while the review is open: they are what the
          // user checks the matches against. `reset` drops them when it closes.
          state = ReceiptScanState(photos: _photos.length, reviewReady: true);
        } else {
          state = ReceiptScanState(
            photos: _photos.length,
            problem: const GeminiFailed(),
          );
        }
      case NoReceipt(:final outcome):
        state = ReceiptScanState(photos: _photos.length, problem: outcome);
    }
  }

  /// What the user confirmed before, as printed key -> product name of the list now (a
  /// pair whose product is gone is left out).
  Future<Map<String, String>> _aliasNames(ListState list) async {
    final listId = ref.read(activeGroupIdProvider);
    if (listId == null) return const {};
    final stored = await ref.read(receiptAliasRepositoryProvider).load(listId);
    final names = {for (final p in list.products) p.id: p.name};
    return {
      for (final e in stored.entries)
        if (names[e.value] != null) e.key: names[e.value]!,
    };
  }

  /// The names the model is told, the ones that matter most first, because a long list
  /// is cut: what is wanted now (a wrong tick hides exactly these), then what is bought
  /// most often, then the rest in list order.
  static List<String> namesByImportance(ListState list) {
    final planned = [
      for (final p in list.products)
        if (p.planned) p,
    ];
    final rest = [
      for (final p in list.products)
        if (!p.planned) p,
    ]..sort((a, b) => b.usage.compareTo(a.usage));
    return [
      for (final p in [...planned, ...rest]) p.name,
    ];
  }

  /// The review screen took over; the next scan starts clean.
  void reviewShown() {
    if (!state.reviewReady) return;
    state = ReceiptScanState(photos: _photos.length);
  }

  void problemShown() {
    if (state.problem == null) return;
    state = ReceiptScanState(photos: _photos.length, busy: state.busy);
  }

  /// The photos of the receipt being read or reviewed (memory only).
  List<Uint8List> get photos => List.unmodifiable(_photos);

  /// Drops the photos (the user gave up, or the review is closed).
  void reset() {
    _photos.clear();
    state = const ReceiptScanState();
  }
}

final receiptScanProvider =
    NotifierProvider<ReceiptScanViewModel, ReceiptScanState>(
      ReceiptScanViewModel.new,
    );
