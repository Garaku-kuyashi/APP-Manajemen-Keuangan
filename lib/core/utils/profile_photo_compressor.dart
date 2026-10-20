import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ProfilePhotoCompressor {
  static const int maxBytes = 680 * 1024;

  static Uint8List compress(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) {
      throw const FormatException(
        'The selected file is not a supported image.',
      );
    }

    var resized = decoded;
    final longestSide = math.max(decoded.width, decoded.height);
    if (longestSide > 512) {
      final scale = 512 / longestSide;
      resized = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
      );
    }

    Uint8List compressed = Uint8List(0);
    for (var quality = 85; quality >= 25; quality -= 10) {
      compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      if (compressed.length <= maxBytes) return compressed;
    }

    while (math.max(resized.width, resized.height) > 128) {
      resized = img.copyResize(
        resized,
        width: (resized.width * 0.75).round(),
        height: (resized.height * 0.75).round(),
      );
      compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 55));
      if (compressed.length <= maxBytes) return compressed;
    }

    throw StateError('Could not compress the image below the size limit.');
  }
}
