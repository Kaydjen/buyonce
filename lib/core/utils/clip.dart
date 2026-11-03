/// The server refuses longer texts (rules: product names 100, group names 60), so the
/// app cuts them first instead of losing the write later. Counts characters, not UTF-16
/// units.
const maxProductNameLength = 100;
const maxGroupNameLength = 60;

String clip(String text, int max) {
  final runes = text.runes;
  if (runes.length <= max) return text;
  return String.fromCharCodes(runes.take(max)).trimRight();
}
