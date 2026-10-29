import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/logging/app_logger.dart';
import 'snapshot_cache.dart';

SnapshotCache createPlatformSnapshotCache() => FileSnapshotCache();

/// JSON files in the app's private support directory (sandboxed, excluded
/// from Android backup via `allowBackup="false"`). Writes are atomic:
/// temporary file + rename, so a crash never leaves a half-written cache.
class FileSnapshotCache with SerializedOperations implements SnapshotCache {
  FileSnapshotCache({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  static final _log = AppLogger('SnapshotCache');

  Future<Directory> _cacheDir() async {
    final dir = Directory('${(await _directory()).path}/home_cache');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // The server URL is hashed so it never appears in file names.
  Future<File> _file(String serverId) async {
    final name = sha256
        .convert(utf8.encode(serverId))
        .toString()
        .substring(0, 32);
    return File('${(await _cacheDir()).path}/$name.json');
  }

  @override
  Future<CachedHome?> load(String serverId) => serialized(() async {
    try {
      final file = await _file(serverId);
      if (!file.existsSync()) return null;
      return CachedHome.tryFromJson(jsonDecode(await file.readAsString()));
    } on Object catch (e) {
      _log.warning('Ignoring unreadable cache', e.runtimeType);
      return null;
    }
  });

  @override
  Future<void> save(String serverId, CachedHome home) => serialized(() async {
    try {
      final file = await _file(serverId);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(home.toJson()), flush: true);
      await tmp.rename(file.path);
    } on Object catch (e) {
      _log.warning('Could not write cache', e.runtimeType);
    }
  });

  @override
  Future<void> clear(String serverId) => serialized(() async {
    try {
      final file = await _file(serverId);
      if (file.existsSync()) await file.delete();
    } on Object catch (e) {
      _log.error('Could not delete cache', e.runtimeType);
    }
  });

  @override
  Future<void> clearAll() => serialized(() async {
    try {
      final dir = await _cacheDir();
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on Object catch (e) {
      _log.error('Could not delete cache', e.runtimeType);
    }
  });
}
