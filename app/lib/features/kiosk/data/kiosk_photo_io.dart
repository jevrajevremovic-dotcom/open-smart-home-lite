import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'kiosk_photo.dart';

class PlatformKioskPhotoStore implements KioskPhotoStore {
  @override
  bool get supported => true;

  @override
  Future<String> save(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    // A new name each time, so the image cache never shows the old photo.
    final file = File(
      '${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.img',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  ImageProvider? image(String path) {
    final file = File(path);
    return file.existsSync() ? FileImage(file) : null;
  }
}
