import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';
import 'accent_dot.dart';
import 'fade_slot.dart';
import 'header_bar.dart';
import 'raised_icon.dart';

/// The top bar of Plan and Shop. Two looks, chosen by the style: text buttons (flat
/// baseline), and a large tappable heading with the status beside it and raised plates.
/// [menu] is the popup menu button, built by the screen.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.shop,
    required this.name,
    required this.toBuyCount,
    required this.onGroup,
    required this.onGroupLongPress,
    required this.onAdd,
    required this.menu,
    this.onScan,
    this.statusKey,
    this.hideStatus = false,
    this.offline = false,
  });

  final bool shop;
  final String name;

  /// The status of Plan; 0 hides it.
  final int toBuyCount;
  final VoidCallback onGroup;
  final VoidCallback? onGroupLongPress;

  /// Opens "add products"; null in Shop.
  final VoidCallback? onAdd;
  final Widget menu;

  /// Scans a receipt; in Shop only, in the place Plan gives to "add".
  final VoidCallback? onScan;

  /// Lets the list measure the status.
  final Key? statusKey;

  /// The status is left out: the search icon docked in the bar would cover it.
  final bool hideStatus;

  /// The app cannot reach the server: a small sign shows left of the menu, only then.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = !shop && toBuyCount > 0 && !hideStatus;
    return HeaderBar(
      shop: shop,
      child: Row(
        children: [
          Expanded(
            child: t.bigHeader
                ? _heading(context, status)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('groupButton'),
                      onPressed: onGroup,
                      onLongPress: onGroupLongPress,
                      style: headerButtonStyle(context),
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: t.controlStyle(
                          Theme.of(context).textTheme.titleMedium!,
                        ),
                      ),
                    ),
                  ),
          ),
          if (!t.bigHeader && status) HeaderStatus(toBuyCount),
          if (t.bigHeader)
            // Shop keeps the place of the button, so a tab switch moves nothing.
            FadeSlot(
              show: onAdd != null || onScan != null,
              space: t.depth > 0 ? 52 : 48,
              // Plan's "add" and Shop's "scan" take turns in one place with a fade.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: onAdd == null && onScan != null
                    ? _scan(context, t.depth > 0)
                    : t.depth > 0
                    ? RaisedIcon(
                        key: const Key('addProducts'),
                        label: context.l10n.addProductsTitle,
                        onPressed: onAdd,
                        child: const Icon(Icons.add),
                      )
                    : IconButton(
                        key: const Key('addProducts'),
                        tooltip: context.l10n.addProductsTitle,
                        onPressed: onAdd,
                        icon: const Icon(Icons.add),
                      ),
              ),
            )
          else if (onAdd != null)
            TextButton(
              key: const Key('addProducts'),
              onPressed: onAdd,
              style: headerButtonStyle(context),
              child: Text(context.l10n.add),
            )
          else if (onScan != null)
            _scan(context, false),
          if (offline) const _OfflineSign(),
          menu,
        ],
      ),
    );
  }

  /// The receipt icon of Shop.
  Widget _scan(BuildContext context, bool raised) {
    final label = context.l10n.scanReceiptTooltip;
    return raised
        ? RaisedIcon(
            key: const Key('scanReceipt'),
            label: label,
            onPressed: onScan,
            child: const Icon(Icons.receipt_long_outlined),
          )
        : IconButton(
            key: const Key('scanReceipt'),
            tooltip: label,
            onPressed: onScan,
            icon: const Icon(Icons.receipt_long_outlined),
          );
  }

  Widget _heading(BuildContext context, bool status) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final statusText = Text.rich(
      key: const Key('toBuyCount'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      TextSpan(
        children: [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: AccentDot(size: 7),
          ),
          const TextSpan(text: '  '),
          TextSpan(
            text: '$toBuyCount',
            style: t.weighted(
              theme.bodyMedium!.copyWith(color: t.text),
              t.titleWeight,
            ),
          ),
          TextSpan(text: ' ${context.l10n.toBuyWord}'),
        ],
      ),
      style: theme.bodyMedium!.copyWith(color: t.muted),
    );
    final statusBox = KeyedSubtree(key: statusKey, child: statusText);
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.weighted(
              t.controlStyle(theme.titleLarge!.copyWith(color: t.text)),
              t.titleWeight,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down, size: 20, color: t.muted),
      ],
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InkWell(
              key: const Key('groupButton'),
              onTap: onGroup,
              onLongPress: onGroupLongPress,
              borderRadius: BorderRadius.circular(t.radiusRow),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: title,
              ),
            ),
          ),
          Flexible(
            child: FadeSlot(
              show: status,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: statusBox,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon only, named for screen readers; it is not a button.
class _OfflineSign extends StatelessWidget {
  const _OfflineSign();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.offline,
    child: Padding(
      key: const Key('offlineSign'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.cloud_off, size: 20, color: context.tokens.muted),
    ),
  );
}
