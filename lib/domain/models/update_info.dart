/// A newer version of the app that can be installed.
class UpdateInfo {
  const UpdateInfo(this.version);
  final String version;
}

/// True when version [a] is newer than [b]; both are "major.minor.patch".
bool isNewerVersion(String a, String b) {
  final x = a.split('.').map(int.parse).toList();
  final y = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final left = i < x.length ? x[i] : 0;
    final right = i < y.length ? y[i] : 0;
    if (left != right) return left > right;
  }
  return false;
}
