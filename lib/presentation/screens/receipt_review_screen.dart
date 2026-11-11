import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/clip.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_names.dart';
import '../../domain/models/receipt_review.dart';
import '../../l10n/l10n.dart';
import '../view_models/list/list_view_model.dart';
import '../view_models/receipt/receipt_review_view_model.dart';
import '../widgets/accent_button.dart';
import '../widgets/amount_editor.dart';
import '../widgets/amount_text.dart';
import '../widgets/card_action.dart';
import '../widgets/card_dialog.dart';
import '../widgets/card_sheet.dart';
import '../widgets/card_title.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/groove.dart';
import '../widgets/inset.dart';
import '../widgets/panel.dart';
import '../widgets/toast.dart';

/// The check of a scanned receipt before anything is written: "Found" products (checked),
/// "New" ones (unchecked), and how many lines were skipped. Back writes nothing; "Mark N"
/// puts the checked rows into the open trip and closes with how many it marked.
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({super.key});

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    // Prices that do not add up: said once, without any amount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(receiptReviewProvider)?.pricesMayBeWrong == true) {
        showToast(context, context.l10n.pricesMayBeMisread);
      }
    });
  }

  ReceiptReviewViewModel get _vm => ref.read(receiptReviewProvider.notifier);

  Future<void> _mark(ReceiptReview review) async {
    if (_marking) return;
    setState(() => _marking = true);
    final n = await ref
        .read(listViewModelProvider.notifier)
        .applyReceipt(review);
    if (mounted) Navigator.of(context).pop(n);
  }

  /// A matched row: another product, or "New product". A new row: its name.
  Future<void> _editName(ReviewRow row) async {
    if (row.isNew) {
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
      return;
    }
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

  Future<void> _editAmount(ReviewRow row) => showAmountEditor(
    context,
    name: row.name,
    initial: row.amount,
    onDone: (amount) {
      if (amount != row.amount) _vm.setAmount(row.id, amount);
    },
  );

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(receiptReviewProvider);
    final t = context.tokens;
    final l10n = context.l10n;
    if (review == null) {
      // The review was dropped (the screen is leaving): nothing to show.
      return const Scaffold(body: SizedBox.shrink());
    }
    final locale = Localizations.localeOf(context).toString();
    final muted = Theme.of(context).textTheme.bodySmall!
        .copyWith(color: t.muted);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(review.store ?? l10n.receiptTitle),
            if (review.date != null)
              Text(DateFormat.yMMMd(locale).format(review.date!), style: muted),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(t.gutter, 8, t.gutter, 120),
        children: [
          if (review.found.isNotEmpty)
            _card(
              key: const Key('foundCard'),
              title: CardTitle(l10n.receiptFound),
              rows: review.found,
            ),
          if (review.fresh.isNotEmpty) ...[
            if (review.found.isNotEmpty) const SizedBox(height: 16),
            _card(
              key: const Key('newCard'),
              title: CardTitle(
                l10n.newLabel,
                trailing: CardIconAction(
                  key: const Key('selectAllNew'),
                  icon: Icons.done_all,
                  label: l10n.selectAllNew,
                  onPressed: () => _vm.setAllNew(
                    // All checked: the same icon clears them.
                    !review.fresh.every((r) => r.checked || r.locked),
                  ),
                ),
              ),
              rows: review.fresh,
            ),
          ],
          if (review.skipped > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text(
                  l10n.receiptSkipped(review.skipped),
                  key: const Key('skippedCount'),
                  style: muted,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: review.checkedCount == 0 ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: review.checkedCount == 0 || _marking,
          child: AccentButton(
            buttonKey: const Key('markReceipt'),
            label: l10n.markCount(review.checkedCount),
            onPressed: () => _mark(review),
          ),
        ),
      ),
    );
  }

  Widget _card({
    required Key key,
    required Widget title,
    required List<ReviewRow> rows,
  }) => Panel(
    key: key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Groove(tight: true),
        ),
        for (var i = 0; i < rows.length; i++)
          _ReviewRowTile(
            key: ValueKey('row-${rows[i].id}'),
            row: rows[i],
            showDivider: i < rows.length - 1,
            onToggle: () => _vm.toggle(rows[i].id),
            onName: () => _editName(rows[i]),
            onAmount: () => _editAmount(rows[i]),
          ),
      ],
    ),
  );
}

/// One row: check, name (the printed text under it when it differs), the amount.
class _ReviewRowTile extends StatelessWidget {
  const _ReviewRowTile({
    super.key,
    required this.row,
    required this.showDivider,
    required this.onToggle,
    required this.onName,
    required this.onAmount,
  });

  final ReviewRow row;
  final bool showDivider;
  final VoidCallback onToggle;
  final VoidCallback onName;
  final VoidCallback onAmount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final locked = row.locked;
    final printed = row.raws
        .where((r) => !ProductNames.same(r, row.name))
        .join(' · ');
    final amount = amountText(context, row.amount);
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
                      if (printed.isNotEmpty)
                        Text(
                          printed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall!.copyWith(color: t.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            InkWell(
              key: ValueKey('amount-${row.id}'),
              onTap: locked ? null : onAmount,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(
                      amount.isEmpty ? context.l10n.amountCount(1) : amount,
                      style: theme.bodyMedium!.copyWith(
                        color: amount.isEmpty ? t.muted : t.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The catalog to point a matched row at; the last row turns it into a new product.
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
          key: const Key('pickNew'),
          title: Text(context.l10n.newProduct),
          onTap: () => widget.onPick(null),
        ),
      ],
    );
  }
}
