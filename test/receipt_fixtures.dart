import 'dart:convert';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';

/// The text of the prompt of a scripted call.
String promptOf(GeminiCall call) {
  final parts =
      ((call.body['contents'] as List).single as Map)['parts'] as List;
  return (parts.first as Map)['text'] as String;
}

/// Is this call the second reader's (text only, the lines of the receipt)?
bool isMatcherCall(GeminiCall call) =>
    promptOf(call).startsWith('These are lines of a shop receipt');

/// A scripted Gemini for the receipt flow. The first call (the photos) gets
/// [reader]; the second reader's call gets [matcher], or by default AGREES with every
/// match of the reader that carries evidence, so that such a match is confirmed.
Result<GeminiReply> receiptReply(
  GeminiCall call,
  String reader, {
  String? matcher,
}) {
  if (!isMatcherCall(call)) return ScriptedGeminiApi.text(reader);
  if (matcher != null) return ScriptedGeminiApi.text(matcher);
  final json = jsonDecode(reader);
  final lines = json is Map && json['lines'] is List
      ? json['lines'] as List
      : const [];
  return ScriptedGeminiApi.text(
    jsonEncode({
      'matches': [
        for (var i = 0; i < lines.length; i++)
          if (lines[i] is Map &&
              (lines[i] as Map)['match'] != null &&
              (lines[i] as Map)['evidence'] != null)
            {
              'index': i,
              'evidence': (lines[i] as Map)['evidence'],
              'match': (lines[i] as Map)['match'],
            },
      ],
    }),
  );
}
