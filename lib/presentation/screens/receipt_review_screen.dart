import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/clip.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_names.dart';
import '../../domain/models/receipt_review.dart';
import '../../l10n/l10n.dart';
import '../view_models/list/list_view_model.dart';
import '../view_models/receipt/receipt_review_view_model.dart';
import '../view_models/receipt/receipt_scan_view_model.dart';
import '../widgets/accent_button.dart';
import '../widgets/card_dialog.dart';
import '../widgets/card_sheet.dart';
import '../widgets/card_title.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/groove.dart';
import '../widgets/inset.dart';
import '../widgets/panel.dart';
import 'receipt_photo_viewer.dart';

/// What a scanned receipt says about the user's LIST, before anything is written.
///
/// The question it answers is "what did I buy from my list?": a headline ("Bought 6 of
/// 9"), the matches the app is not sure of ("Check these", unticked, each with the
/// printed line and its reading beside it), the matches it is sure of ("On the
/// receipt", ticked), the planned products the receipt does not show ("Not on the
/// receipt", so a forgotten one is seen), and the other lines of the receipt folded
/// into one row. The photo of the receipt is one tap away for checking against it.
/// Back writes nothing; the button ticks the checked rows and closes with how many.
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({super.key});

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  bool _marking = false;
  bool _showOthers = false;

  ReceiptReviewViewModel get _vm => ref.read(receiptReviewProvider.notifier);

  Future<void> _mark(ReceiptReview review) async {
    if (_marking) return;
    setState(() => _marking = true);
    final n = await ref
        .read(listViewModelProvider.notifier)
        .applyReceipt(review);
    if (mounted) Navigator.of(context).pop(n);
  }

  void _openPhotos() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReceiptPhotoViewer(
        photos: ref.read(receiptScanProvider.notifier).photos,
      ),
    ),
  );

  /// A line of the receipt that is not on the list: a new name for it.
  Future<void> _rename(ReviewRow row) async {
    final l10n = context.l10n;
    await showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: l10n.rename,
        hint: l10n.nameHint,
        confirm: l10n.save,
        initial: row.name,
        maxLength: maxProductNameLength,
        onSubmit: (text) async {
          if (ProductNames.normalize(text).isEmpty) return l10n.enterName;
          _vm.rename(row.id, text);
          return null;
        },
      ),
    );
  }

  /// A match that is wrong: another product of the list, or "None of these".
  Future<void> _pickProduct(ReviewRow row) async {
    final products =
        ref.read(listViewModelProvider).value?.products ?? const [];
    await showCardSheet<void>(
      context,
      builder: (_) => _ProductPicker(
        products: products,
        current: row.product,
        onPick: (p) {
          Navigator.of(context).pop();
          _vm.pick(row.id, p);
        },
      ),
    );
  }

  /// A product the receipt does not show: which printed line is it after all?
  Future<void> _linkLine(Product product, List<ReviewRow> lines) async {
    await showCardSheet<void>(
      context,
      builder: (_) => SheetCard(
        children: [
          for (final line in lines)
            ListTile(
              key: ValueKey('link-${line.id}'),
              title: Text(
                line.raws.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(context).pop();
                _vm.pick(line.id, product);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(receiptReviewProvider);
    final t = context.tokens;
    final l10n = context.l10n;
    if (review == null) {
      // The review was dropped (the screen is leaving): nothing to show.
      return const Scaffold(body: SizedBox.shrink());
    }
    final hasPhotos = ref.watch(
      receiptScanProvider.select((s) => s.photos > 0),
    );
    final others = review.fresh;
    return Scaffold(
      appBar: AppBar(
        title: Text(review.store ?? l10n.receiptTitle),
        actions: [
          if (hasPhotos)
            IconButton(
              key: const Key('viewReceipt'),
              tooltip: l10n.receiptViewTooltip,
              onPressed: _openPhotos,
              icon: const Icon(Icons.receipt_long_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(t.gutter, 8, t.gutter, 120),
        children: [
          if (review.listSize > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Text(
                l10n.receiptBoughtOf(review.listBought, review.listSize),
                key: const Key('boughtHeader'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          if (review.toCheck.isNotEmpty)
            _card(
              key: const Key('checkCard'),
              title: l10n.receiptCheckTitle,
              rows: review.toCheck,
            ),
          if (review.confirmed.isNotEmpty) ...[
            if (review.toCheck.isNotEmpty) const SizedBox(height: 16),
            _card(
              key: const Key('inCard'),
              title: l10n.receiptInTitle,
              rows: review.confirmed,
            ),
          ],
          if (review.missing.isNotEmpty) ...[
            const SizedBox(height: 16),
            _missingCard(review.missing, others),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            _othersCard(others),
          ],
        ],
      ),
      floatingActionButton: AccentButton(
        buttonKey: const Key('markReceipt'),
        label: l10n.markCount(review.checkedCount),
        onPressed: review.checkedCount == 0 || _marking
            ? null
            : () => _mark(review),
      ),
    );
  }

  Widget _card({
    required Key key,
    required String title,
    required List<ReviewRow> rows,
  }) => Panel(
    key: key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardTitle(title),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Groove(tight: true),
        ),
        for (var i = 0; i < rows.length; i++)
          _RowTile(
            key: ValueKey('row-${rows[i].id}'),
            row: rows[i],
            showDivider: i < rows.length - 1,
            onToggle: () => _vm.toggle(rows[i].id),
            onName: () => _pickProduct(rows[i]),
          ),
      ],
    ),
  );

  Widget _missingCard(List<Product> missing, List<ReviewRow> lines) => Panel(
    key: const Key('missingCard'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardTitle(context.l10n.receiptMissingTitle),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Groove(tight: true),
        ),
        for (var i = 0; i < missing.length; i++)
          _MissingTile(
            key: ValueKey('missing-${missing[i].id}'),
            product: missing[i],
            showDivider: i < missing.length - 1,
            // A printed line can be pointed at only when the receipt has spare ones.
            onTap: lines.isEmpty ? null : () => _linkLine(missing[i], lines),
          ),
      ],
    ),
  );

  /// The lines that are not on the list, folded: nothing happens to them unless the
  /// user opens the row and ticks one (it then becomes a new product and is marked).
  Widget _othersCard(List<ReviewRow> others) => Panel(
    key: const Key('othersCard'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const Key('moreLines'),
          onTap: () => setState(() => _showOthers = !_showOthers),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.receiptMoreLines(others.length),
                      style: Theme.of(context).textTheme.bodyLarge!
                          .copyWith(color: context.tokens.muted),
                    ),
                  ),
                  Icon(
                    _showOthers ? Icons.expand_less : Icons.expand_more,
                    color: context.tokens.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showOthers)
          for (var i = 0; i < others.length; i++)
            _RowTile(
              key: ValueKey('row-${others[i].id}'),
              row: others[i],
              showDivider: i < others.length - 1,
              onToggle: () => _vm.toggle(others[i].id),
              onName: () => _rename(others[i]),
            ),
      ],
    ),
  );
}

/// One match: check, the product, the printed text under it, and for a candidate the
/// reader's reading of that text.
class _RowTile extends StatelessWidget {
  const _RowTile({
    super.key,
    required this.row,
    required this.showDivider,
    required this.onToggle,
    required this.onName,
  });

  final ReviewRow row;
  final bool showDivider;
  final VoidCallback onToggle;
  final VoidCallback onName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final locked = row.locked;
    final muted = theme.bodySmall!.copyWith(color: t.muted);
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: t.line))
              : null,
        ),
        child: Row(
          children: [
            IconButton(
              key: ValueKey('check-${row.id}'),
              onPressed: locked ? null : onToggle,
              icon: Icon(
                row.checked ? Icons.check_box : Icons.check_box_outline_blank,
                color: row.checked ? t.text : t.muted,
              ),
            ),
            Expanded(
              child: InkWell(
                key: ValueKey('name-${row.id}'),
                onTap: locked ? null : onName,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyLarge,
                      ),
                      Text(
                        row.raws.join(' · '),
                        key: ValueKey('printed-${row.id}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                      if (row.doubtful && row.meaning != null)
                        Text(
                          row.meaning!,
                          key: ValueKey('meaning-${row.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// A planned product the receipt does not show.
class _MissingTile extends StatelessWidget {
  const _MissingTile({
    super.key,
    required this.product,
    required this.showDivider,
    required this.onTap,
  });

  final Product product;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: t.line))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: t.muted),
          ],
        ),
      ),
    );
  }
}

/// The list to point a match at; the last row sends the line back to "other lines".
class _ProductPicker extends StatefulWidget {
  const _ProductPicker({
    required this.products,
    required this.current,
    required this.onPick,
  });

  final List<Product> products;
  final Product? current;
  final ValueChanged<Product?> onPick;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final p in widget.products)
        if (q.isEmpty || p.name.toLowerCase().contains(q)) p,
    ];
    final height = MediaQuery.sizeOf(context).height * 0.45;
    return SheetCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SoftField(
            child: TextField(
              key: const Key('pickerSearch'),
              autofocus: true,
              decoration: InputDecoration(hintText: context.l10n.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in shown)
                ListTile(
                  key: ValueKey('pick-${p.id}'),
                  title: Text(p.name),
                  trailing: p.id == widget.current?.id
                      ? Icon(Icons.check, color: t.text)
                      : null,
                  onTap: () => widget.onPick(p),
                ),
            ],
          ),
        ),
        ListTile(
          key: const Key('pickNone'),
          title: Text(context.l10n.receiptNoneOfThese),
          onTap: () => widget.onPick(null),
        ),
      ],
    );
  }
}
