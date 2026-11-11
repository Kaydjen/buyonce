import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../data/repositories/receipt_parsing_repository.dart';
import '../../../data/services/photo_service.dart';
import '../../../domain/models/gemini_outcome.dart';
import '../../../domain/models/gemini_task.dart';
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
/// are dropped when the review opens or on [reset]; nothing is stored anywhere.
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

  /// A photo taken before Android killed the app is not wasted.
  Future<bool> recoverLost() async {
    final lost = await ref.read(photoServiceProvider).recoverLostPhoto();
    if (!ref.mounted || lost == null || !state.canAddPhoto) return false;
    _photos.add(lost);
    state = ReceiptScanState(photos: _photos.length);
    return true;
  }

  /// Reads the photos taken so far and opens the review. [language] is the English name
  /// of the app language; [fallbackCurrency] an ISO code for a receipt that shows none.
  /// On success the photos are dropped; on a problem they stay for a retry.
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
    final result = await ref
        .read(receiptParsingRepositoryProvider)
        .read(
          List.of(_photos),
          language: language,
          models: models,
          knownNames: [for (final p in list.products) p.name],
          fallbackCurrency: fallbackCurrency,
        );
    if (!ref.mounted) return;
    switch (result) {
      case ParsedReceipt(:final reading):
        final started = ref.read(receiptReviewProvider.notifier).begin(reading);
        if (started) {
          _photos.clear();
          state = const ReceiptScanState(reviewReady: true);
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

  /// The review screen took over; the next scan starts clean.
  void reviewShown() {
    if (!state.reviewReady) return;
    state = const ReceiptScanState();
  }

  void problemShown() {
    if (state.problem == null) return;
    state = ReceiptScanState(photos: _photos.length, busy: state.busy);
  }

  /// Drops the photos (the user gave up).
  void reset() {
    _photos.clear();
    state = const ReceiptScanState();
  }
}

final receiptScanProvider =
    NotifierProvider<ReceiptScanViewModel, ReceiptScanState>(
      ReceiptScanViewModel.new,
    );
