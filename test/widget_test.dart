import 'package:flutter_test/flutter_test.dart';

void main() {
  group('URL Validation Tests', () {
    bool isValidUrl(String text) {
      return text.contains('youtube.com') ||
          text.contains('youtu.be') ||
          text.contains('instagram.com');
    }

    test('Valid YouTube links should return true', () {
      expect(isValidUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(isValidUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
    });

    test('Valid Instagram links should return true', () {
      expect(isValidUrl('https://www.instagram.com/reel/C8k/'), isTrue);
      expect(isValidUrl('https://instagram.com/p/C8k/'), isTrue);
    });

    test('Invalid links should return false', () {
      expect(isValidUrl('https://www.google.com'), isFalse);
      expect(isValidUrl('https://twitter.com/home'), isFalse);
      expect(isValidUrl('random string'), isFalse);
    });
  });
}
