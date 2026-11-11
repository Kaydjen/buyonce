import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/gemini_outcome.dart';
import '../../domain/models/gemini_task.dart';
import '../../l10n/l10n.dart';
import '../view_models/receipt/receipt_review_view_model.dart';
import '../view_models/receipt/receipt_scan_view_model.dart';
import '../view_models/settings/gemini_key_view_model.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/toast.dart';
import 'models_screen.dart';
import 'receipt_camera_screen.dart';
import 'receipt_review_screen.dart';
import 'receipt_scan_format.dart';

/// The whole "scan a receipt" gesture of the Shop top bar: the key, then the camera
/// screen (shots, gallery, reading), then the review. Photos live in memory and go
/// when the review closes or the camera is left.
Future<void> startReceiptScan(BuildContext context, WidgetRef ref) async {
  if (await ref.read(geminiKeyProvider.future) == null) {
    if (!context.mounted) return;
    await showApiKeyDialog(context, ref);
    if (!context.mounted || await ref.read(geminiKeyProvider.future) == null) {
      return;
    }
  }
  if (!context.mounted) return;
  final scan = ref.read(receiptScanProvider.notifier);
  if (ref.read(receiptScanProvider).busy) return;
  scan.reset();
  final reviewReady = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => const ReceiptCameraScreen()));
  if (reviewReady != true) {
    // The camera was left: nothing was read, nothing is kept.
    scan.reset();
    return;
  }
  if (!context.mounted) return;
  await _openReview(context, ref);
}

/// The review of a scanned receipt; leaving it drops the review and the photos, "Check
/// off N" has written the marks by then.
Future<void> _openReview(BuildContext context, WidgetRef ref) async {
  ref.read(receiptScanProvider.notifier).reviewShown();
  final marked = await Navigator.of(
    context,
  ).push<int>(MaterialPageRoute(builder: (_) => const ReceiptReviewScreen()));
  ref.read(receiptReviewProvider.notifier).discard();
  ref.read(receiptScanProvider.notifier).reset();
  if (marked != null && marked > 0 && context.mounted) {
    showToast(
      context,
      context.l10n.markedCount(marked),
      duration: const Duration(seconds: 2),
    );
  }
}

/// The toast for a reading that gave nothing; the photos are still there, so "Retry"
/// reads them again (a broken camera, with no photo yet, starts over).
void showReceiptProblem(
  BuildContext context,
  WidgetRef ref,
  GeminiOutcome problem,
) {
  final scan = ref.read(receiptScanProvider.notifier);
  scan.problemShown();
  final l10n = context.l10n;
  Future<void> retry() async {
    if (!context.mounted) return;
    if (ref.read(receiptScanProvider).photos == 0) {
      await startReceiptScan(context, ref);
    } else {
      await scan.read(
        language: receiptLanguage(context),
        fallbackCurrency: receiptFallbackCurrency(context),
      );
    }
  }

  void openModels() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const ModelsScreen(task: GeminiTask.receipts),
    ),
  );
  Future<void> keyThenRetry() async {
    await showApiKeyDialog(context, ref);
    if (context.mounted && await ref.read(geminiKeyProvider.future) != null) {
      await retry();
    }
  }

  switch (problem) {
    case GeminiLimited(:final model):
      showToast(
        context,
        l10n.modelLimitReached(model),
        actionLabel: l10n.addModels,
        onAction: openModels,
      );
    case GeminiAllLimited():
      showToast(
        context,
        l10n.allModelsLimited,
        actionLabel: l10n.addModels,
        onAction: openModels,
      );
    case GeminiOffline():
      showToast(
        context,
        l10n.noConnection,
        actionLabel: l10n.retry,
        accentAction: true,
        onAction: retry,
      );
    case GeminiBadKey():
      showToast(
        context,
        l10n.apiKeyRejected,
        actionLabel: l10n.apiKey,
        onAction: keyThenRetry,
      );
    case GeminiNoKey():
      keyThenRetry();
    case GeminiFailed() || GeminiOk():
      showToast(
        context,
        l10n.couldntReadReceipt,
        actionLabel: l10n.retry,
        onAction: retry,
      );
  }
}
