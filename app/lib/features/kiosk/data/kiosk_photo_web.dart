import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'kiosk_photo.dart';

/// Browsers get the gradients only (no local file storage).
class PlatformKioskPhotoStore implements KioskPhotoStore {
  @override
  bool get supported => false;

  @override
  Future<String> save(Uint8List bytes) =>
      throw UnsupportedError('no kiosk photo on web');

  @override
  Future<void> delete(String path) async {}

  @override
  ImageProvider? image(String path) => null;
}
