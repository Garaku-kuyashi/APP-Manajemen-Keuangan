import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mymoney/core/utils/profile_photo_compressor.dart';

void main() {
  group('ProfilePhotoCompressor', () {
    test('compresses photos below the Firestore document size budget', () {
      final source = img.Image(width: 1600, height: 1200);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(
            x,
            y,
            (x * 31 + y * 17) % 256,
            (x * 13 + y * 29) % 256,
            (x * 7 + y * 43) % 256,
          );
        }
      }
      final original = Uint8List.fromList(img.encodePng(source));

      final compressed = ProfilePhotoCompressor.compress(original);

      expect(compressed.length, lessThanOrEqualTo(680 * 1024));
      expect(compressed.length, lessThan(1024 * 1024));
      expect(base64Encode(compressed).length, lessThan(950000));
      expect(img.decodeImage(compressed), isNotNull);
    });

    test('rejects unsupported image data', () {
      expect(
        () => ProfilePhotoCompressor.compress(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });
}
