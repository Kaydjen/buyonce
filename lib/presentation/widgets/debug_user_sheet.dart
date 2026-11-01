import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/group.dart';
import '../view_models/users/user_names_view_model.dart';

/// Debug only: choose which of the two fake users this phone acts as.
Future<String?> showDebugUserSheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in groupUserIds)
              ListTile(
                title: Text(ref.watch(userNameProvider(id))),
                trailing: id == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(id),
              ),
          ],
        ),
      ),
    ),
  );
}
