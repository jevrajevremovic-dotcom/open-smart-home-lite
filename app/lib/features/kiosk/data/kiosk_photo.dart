import 'dart:typed_data';

import 'package:flutter/widgets.dart';

export 'kiosk_photo_io.dart'
    if (dart.library.js_interop) 'kiosk_photo_web.dart';

/// Stores photos on the device (photo frame, room photos; not on web).
abstract interface class KioskPhotoStore {
  bool get supported;

  /// Saves [bytes] and returns the path to remember in the settings.
  Future<String> save(Uint8List bytes);
  Future<void> delete(String path);
  ImageProvider? image(String path);
}
