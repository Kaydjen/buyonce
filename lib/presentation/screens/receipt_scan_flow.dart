import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/receipt_parsing_repository.dart';
import '../../domain/models/gemini_outcome.dart';
import '../../domain/models/gemini_task.dart';
import '../../l10n/l10n.dart';
import '../view_models/receipt/receipt_scan_view_model.dart';
import '../view_models/settings/gemini_key_view_model.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/card_dialog.dart';
import '../widgets/plain_button.dart';
import '../widgets/toast.dart';
import 'models_screen.dart';

/// What the dialog after a shot decides.
enum _Next { more, read }

/// The English name of the app language, for names the model has to invent.
String _language(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'uk'
    ? 'Ukrainian'
    : 'English';

/// A currency for a receipt that prints none: the phone's own region.
String _fallbackCurrency(BuildContext context) =>
    NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toLanguageTag(),
    ).currencyName ??
    'USD';

/// The whole "scan a receipt" gesture of the Shop top bar: key, camera, "one more photo
/// or read", reading. Ends with the review ready in `receiptReviewProvider` (the screen
/// that shows it is step 68.4) or with a problem the screen shows as a toast.
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
  await _shoot(context, ref);
}

/// Takes shots until the user chooses to read (or the limit is reached), then reads.
Future<void> _shoot(BuildContext context, WidgetRef ref) async {
  final scan = ref.read(receiptScanProvider.notifier);
  while (true) {
    await scan.addPhoto();
    if (!context.mounted) return;
    final taken = ref.read(receiptScanProvider);
    // A closed camera before the first shot, or a broken one (its toast is shown).
    if (taken.photos == 0) return;
    if (taken.photos >= ReceiptParsingRepository.maxPhotos) break;
    final next = await _askNext(context, taken.photos);
    if (!context.mounted) return;
    if (next == null) {
      scan.reset();
      return;
    }
    if (next == _Next.read) break;
  }
  await scan.read(
    language: _language(context),
    fallbackCurrency: _fallbackCurrency(context),
  );
}

Future<_Next?> _askNext(BuildContext context, int photos) {
  final l10n = context.l10n;
  return showCardDialog<_Next>(
    context,
    builder: (dialog) => CardDialog(
      title: l10n.receiptPhotosTitle(photos),
      cancel: PlainButton(
        key: const Key('receiptMore'),
        label: l10n.addPhoto,
        onPressed: () => Navigator.of(dialog).pop(_Next.more),
      ),
      confirm: PlainButton(
        key: const Key('receiptRead'),
        label: l10n.readReceipt,
        raised: true,
        onPressed: () => Navigator.of(dialog).pop(_Next.read),
      ),
    ),
  );
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
        language: _language(context),
        fallbackCurrency: _fallbackCurrency(context),
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
