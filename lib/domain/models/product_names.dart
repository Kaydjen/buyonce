import '../../core/utils/clip.dart';
import 'product.dart';

enum NameProblem { empty, duplicate }

/// A name after cleaning and what is wrong with it, if anything.
class NameCheck {
  const NameCheck(this.name, this.problem);
  final String name;
  final NameProblem? problem;

  bool get ok => problem == null;
}

/// The one rule for a product name, shared by typing, renaming and suggestions: no
/// spaces around or doubled inside, at most [maxProductNameLength] characters, not empty,
/// and not the name of another product (any letter case).
abstract final class ProductNames {
  static String normalize(String raw) =>
      clip(raw.trim().replaceAll(RegExp(r'\s+'), ' '), maxProductNameLength);

  /// The same name in any letter case.
  static bool same(String a, String b) =>
      normalize(a).toLowerCase() == normalize(b).toLowerCase();

  /// [products] are the products that count (the active ones of the list); the product
  /// with [selfId] is left out, so renaming to its own name in another case is allowed.
  static NameCheck check(
    String raw,
    Iterable<Product> products, {
    String? selfId,
  }) {
    final name = normalize(raw);
    if (name.isEmpty) return const NameCheck('', NameProblem.empty);
    final taken = products.any((p) => p.id != selfId && same(p.name, name));
    return NameCheck(name, taken ? NameProblem.duplicate : null);
  }
}
