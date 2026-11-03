import 'package:buyonce/core/utils/clip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short texts stay, long ones are cut by characters', () {
    expect(clip('Milk', 100), 'Milk');
    expect(clip('a' * 120, maxProductNameLength).length, 100);
    // Emoji are two UTF-16 units but one character.
    expect(clip('🥛' * 70, maxGroupNameLength).runes.length, 60);
  });
}
