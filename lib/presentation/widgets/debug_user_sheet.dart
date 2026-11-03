import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/group.dart';
import '../view_models/session/session.dart';
import '../view_models/users/user_names_view_model.dart';
import 'card_sheet.dart';

/// Debug only: choose which of the two fake users this phone acts as.
Future<String?> showDebugUserSheet(BuildContext context, String current) {
  return showCardSheet<String>(
    context,
    builder: (context) => Consumer(
      builder: (context, ref, _) => SheetCard(
        children: [
          for (final id in groupUserIds)
            ListTile(
              // The first fake user is the person holding the phone: after a real sign-in the
              // name is stored under the backend id.
              title: Text(
                ref.watch(
                  userNameProvider(
                    id == groupUserIds.first
                        ? ref.watch(realUserIdProvider) ?? id
                        : id,
                  ),
                ),
              ),
              trailing: id == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(id),
            ),
        ],
      ),
    ),
  );
}
