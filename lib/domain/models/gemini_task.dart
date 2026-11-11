/// The models tried for a photo, best first. Chosen with real photos (notes in plan.md,
/// step 64.0): the cheap fast one first, then its sibling, then the bigger one whose free
/// daily limit is small.
const defaultItemModels = [
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
  'gemini-3.8-flash',
];

/// The models tried for a receipt, best first. Chosen 2026-11-11 with 5 real Polish
/// receipts (step 68.1, live): the two flash-lite models read them all, 3-10 s each;
/// gemini-3.8-flash failed every request in that run, so it is the last resort, as for
/// item photos. A small sample: change the order when real use says otherwise.
const defaultReceiptModels = [
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
  'gemini-3.8-flash',
];

/// What the user asks Gemini for. Each task has its own list of models, because a
/// receipt needs a stronger reader than a product name.
enum GeminiTask {
  items(defaultItemModels),
  receipts(defaultReceiptModels);

  const GeminiTask(this.defaultModels);

  final List<String> defaultModels;
}

/// One model the key can use, as the picker shows it.
class GeminiModelInfo {
  const GeminiModelInfo(this.id, this.displayName);

  /// Bare id (`gemini-3.5-flash-lite`).
  final String id;
  final String displayName;
}
