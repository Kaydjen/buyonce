int _counter = 0;

/// Local unique id; replaced by backend-generated ids later.
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_counter++).toRadixString(36)}';
