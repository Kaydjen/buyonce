import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/clip.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_names.dart';
import '../../l10n/l10n.dart';
import '../view_models/list/archive_view_model.dart';
import '../view_models/list/list_view_model.dart';
import '../widgets/card_dialog.dart';
import '../widgets/edge_fade.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/titled_card.dart';

/// The deleted products, the latest deleted first. A tap opens a dialog with the name to
/// edit and "Restore"; the product comes back not needed, on top of the list.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedProductsProvider);
    final t = context.tokens;
    final products = archived.value ?? const <Product>[];
    // The last product is restored: there is nothing left to show.
    if (archived.hasValue && products.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.archive)),
      body: EdgeFade(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            t.gutter,
            t.listTopPadding,
            t.gutter,
            24,
          ),
          child: TitledCard(
            title: context.l10n.archive,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final p in products)
                  ListTile(
                    key: Key('archive-${p.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name),
                    onTap: () => _restore(context, ref, p),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, Product p) {
    final l10n = context.l10n;
    final vm = ref.read(listViewModelProvider.notifier);
    return showCardDialog<void>(
      context,
      builder: (_) => PromptDialog(
        title: l10n.restore,
        hint: l10n.nameHint,
        confirm: l10n.restore,
        initial: p.name,
        maxLength: maxProductNameLength,
        onSubmit: (text) async => switch (await vm.restoreProduct(p, text)) {
          null => null,
          NameProblem.duplicate => l10n.nameTaken,
          NameProblem.empty => l10n.enterName,
        },
      ),
    );
  }
}
