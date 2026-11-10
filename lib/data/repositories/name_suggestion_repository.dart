import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/gemini_outcome.dart';
import '../../domain/models/product_names.dart';
import 'gemini_client.dart';

/// What a photo gave: names to pick from, or the reason there are none.
sealed class NameSuggestions {
  const NameSuggestions();
}

final class SuggestedNames extends NameSuggestions {
  const SuggestedNames(this.names, this.model);

  /// One to three clean names, the likeliest first.
  final List<String> names;
  final String model;
}

final class NoSuggestions extends NameSuggestions {
  const NoSuggestions(this.outcome);

  /// Never a [GeminiOk]: that is a [SuggestedNames].
  final GeminiOutcome outcome;
}

/// The task "name the item on this photo", on top of [GeminiClient].
class NameSuggestionRepository {
  NameSuggestionRepository(this._client);
  final GeminiClient _client;

  static const maxNames = 3;

  /// Called when the camera opens: the connection is ready when the photo is.
  Future<void> warmUp() => _client.warmUp();

  static const schema = <String, Object?>{
    'type': 'OBJECT',
    'properties': {
      'names': {
        'type': 'ARRAY',
        'minItems': 1,
        'maxItems': maxNames,
        'items': {'type': 'STRING'},
      },
    },
    'required': ['names'],
  };

  /// [photo] is a JPEG. [language] is the English name of the app language ("Ukrainian"),
  /// used only for items with no readable name. [knownNames] are names already in the
  /// list: when the item is one of them, the model should give that exact name first (the
  /// photo flow does not pass them yet; a receipt will).
  Future<NameSuggestions> suggest(
    Uint8List photo, {
    required String language,
    required List<String> models,
    List<String> knownNames = const [],
  }) async {
    final outcome = await _client.generate(
      GeminiRequest(
        prompt: prompt(language, knownNames),
        schema: schema,
        image: photo,
      ),
      models,
    );
    if (outcome is! GeminiOk) return NoSuggestions(outcome);
    final names = parseNames(outcome.text);
    if (names.isEmpty) return const NoSuggestions(GeminiFailed());
    return SuggestedNames(names, outcome.model);
  }

  /// Most knownNames a prompt carries: a long catalog is cut, the answer does not need it
  /// all.
  static const maxKnownNames = 300;

  static String prompt(String language, List<String> knownNames) {
    final known = knownNames.take(maxKnownNames).toList();
    return [
      'The photo shows one grocery or household item that the user wants to add to a '
          'shopping list.',
      'Suggest 1 to 3 short names for the shopping list, most likely first.',
      'If the packaging shows the product name, write it exactly as printed on the '
          'packaging, in its original language, and never translate it. Keep the brand '
          'when it is printed as part of the name.',
      'Only when no product name is readable on the photo (loose fruit, vegetables, '
          'unlabeled items), name the item in $language.',
      'Each name has 1 to 5 words and no quantity and no punctuation at the end. Use '
          'normal capitalisation (first letter upper case), not ALL CAPS, even when the '
          'packaging is printed in capitals.',
      if (known.isNotEmpty)
        'The shopping list already has these names: ${known.join('; ')}. If the item '
            'is one of them, give that exact name first.',
    ].join(' ');
  }

  /// The names of an answer: cleaned, in sentence case when the model shouted, without
  /// a closing punctuation mark, no repeats (any letter case), at most [maxNames]. A
  /// broken answer gives an empty list.
  static List<String> parseNames(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } catch (_) {
      return const [];
    }
    final raw = json is Map ? json['names'] : null;
    if (raw is! List) return const [];
    final names = <String>[];
    for (final item in raw) {
      if (item is! String) continue;
      var name = ProductNames.normalize(item)
          .replaceAll(RegExp(r'[.,;:!]+$'), '');
      name = _unshout(name);
      if (name.isEmpty || names.any((n) => ProductNames.same(n, name))) {
        continue;
      }
      names.add(name);
      if (names.length == maxNames) break;
    }
    return names;
  }

  /// "ZIEMNIAKI" -> "Ziemniaki": a name of four or more letters with no lower-case letter is lowered and
  /// its first letter raised. Mixed case ("tołpa", "Piątnica Skyr") stays as it is.
  static String _unshout(String name) {
    final letters = name.runes
        .map(String.fromCharCode)
        .where((c) => c.toLowerCase() != c.toUpperCase())
        .toList();
    if (letters.length < 4 || letters.any((c) => c == c.toLowerCase())) {
      return name;
    }
    final lower = name.toLowerCase();
    final first = lower.runes.first;
    return String.fromCharCode(first).toUpperCase() +
        String.fromCharCodes(lower.runes.skip(1));
  }
}

final nameSuggestionRepositoryProvider = Provider(
  (ref) => NameSuggestionRepository(ref.watch(geminiClientProvider)),
);
