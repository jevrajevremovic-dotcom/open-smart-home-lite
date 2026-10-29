import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/logging/app_logger.dart';
import '../authentication/application/session_controller.dart';
import 'board_page.dart';

/// One saved version of a page in Home Assistant's `image_upload`.
@immutable
class BoardImage {
  const BoardImage({
    required this.imageId,
    required this.pageId,
    required this.savedAt,
  });

  final String imageId;
  final String pageId;

  /// From the file name (milliseconds), so ordering does not depend on
  /// clocks of different devices agreeing exactly.
  final int savedAt;

  /// Board pictures are named `osh-board_<page>_<millis>.png`; other images
  /// in Home Assistant (people's pictures…) are left alone.
  static final _name = RegExp(r'^osh-board_([a-z0-9]{6,32})_(\d{1,16})\.png$');

  static BoardImage? fromItem(Object? item) {
    if (item is! Map) return null;
    final id = item['id'];
    final name = item['name'];
    if (id is! String || name is! String) return null;
    final m = _name.firstMatch(name);
    if (m == null) return null;
    return BoardImage(
      imageId: id,
      pageId: m.group(1)!,
      savedAt: int.parse(m.group(2)!),
    );
  }

  static String fileName(String pageId, int savedAt) =>
      'osh-board_${pageId}_$savedAt.png';

  String get path => '/api/image/serve/$imageId/original';
}

/// All board pictures in Home Assistant, live (`image/subscribe`), by image
/// id.
final boardImagesProvider = StreamProvider.autoDispose<Map<String, BoardImage>>(
  (ref) async* {
    final manager = ref.watch(webSocketManagerProvider);
    final connected = ref.watch(
      connectionStatusProvider.select((s) => s.value?.isConnected ?? false),
    );
    if (manager == null || !connected) {
      throw const AppFailure(FailureKind.webSocket);
    }
    final images = <String, BoardImage>{};
    // `image/subscribe` (storage collection): a first event with every
    // image, then each change. Errors (connection lost) reach the provider,
    // which runs again once the connection is back.
    yield* manager.subscribeCommand({'type': 'image/subscribe'}).map((event) {
      for (final change in event['changes'] as List? ?? const []) {
        if (change is! Map) continue;
        if (change['change_type'] == 'removed') {
          images.remove(change['image_id']);
        } else if (BoardImage.fromItem(change['item']) case final image?) {
          images[image.imageId] = image;
        }
      }
      return Map<String, BoardImage>.unmodifiable(images);
    });
  },
);

/// Pages, newest first: the latest version of each.
final boardPagesProvider = Provider.autoDispose<AsyncValue<List<BoardImage>>>((
  ref,
) {
  return ref.watch(boardImagesProvider).whenData((images) {
    final latest = <String, BoardImage>{};
    for (final i in images.values) {
      final current = latest[i.pageId];
      if (current == null || i.savedAt > current.savedAt) latest[i.pageId] = i;
    }
    return latest.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  });
});

/// The content of one saved version (immutable, so cached by image id).
final boardContentProvider = FutureProvider.family<BoardPage, BoardImage>((
  ref,
  image,
) async {
  final api = ref.watch(homeAssistantApiProvider);
  if (api == null) throw const AppFailure(FailureKind.webSocket);
  final json = extractBoardData(await api.fetchImage(image.path));
  final page = json == null ? null : BoardPage.tryParse(image.pageId, json);
  // A picture with our name but no readable page: shown as empty.
  return page ?? BoardPage(id: image.pageId);
});

class BoardRepository {
  BoardRepository(this._ref);

  final Ref _ref;
  static final _log = AppLogger('Board');
  static final _random = Random.secure();

  /// Images this device uploaded, so their arrival is not mistaken for an
  /// edit made elsewhere.
  final Set<String> ownImages = {};

  static String newPageId() => [
    for (var i = 0; i < 12; i++)
      'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
  ].join();

  /// Uploads [page] as a new version, then removes older versions when this
  /// user may (deleting images needs an administrator).
  Future<BoardImage> save(BoardPage page) async {
    final api = _ref.read(homeAssistantApiProvider);
    if (api == null) throw const AppFailure(FailureKind.webSocket);
    final png = await encodeBoardPng(page);
    final savedAt = DateTime.now().millisecondsSinceEpoch;
    final id = await api.uploadImage(
      png,
      BoardImage.fileName(page.id, savedAt),
    );
    ownImages.add(id);
    final saved = BoardImage(imageId: id, pageId: page.id, savedAt: savedAt);
    final older = [
      for (final i
          in _ref.read(boardImagesProvider).value?.values ??
              const <BoardImage>[])
        if (i.pageId == page.id && i.imageId != id) i.imageId,
    ];
    unawaited(_deleteQuietly(older));
    return saved;
  }

  Future<void> _deleteQuietly(List<String> ids) async {
    for (final id in ids) {
      try {
        await _delete(id);
      } on AppFailure catch (e) {
        // Not an administrator: older versions stay; only the newest shows.
        _log.info('older board version kept: ${e.kind.name}');
        return;
      }
    }
  }

  Future<void> _delete(String imageId) async {
    final manager = _ref.read(webSocketManagerProvider);
    if (manager == null) throw const AppFailure(FailureKind.webSocket);
    await manager.sendCommand({'type': 'image/delete', 'image_id': imageId});
  }

  /// Removes every version of a page. Throws (authorization) when this
  /// user may not delete images.
  Future<void> deletePage(String pageId) async {
    final ids = [
      for (final i
          in _ref.read(boardImagesProvider).value?.values ??
              const <BoardImage>[])
        if (i.pageId == pageId) i.imageId,
    ];
    for (final id in ids) {
      await _delete(id);
    }
  }
}

final boardRepositoryProvider = Provider<BoardRepository>(BoardRepository.new);

/// For tests: decode without Home Assistant.
@visibleForTesting
BoardPage? decodeBoardPng(String pageId, Uint8List png) {
  final json = extractBoardData(png);
  return json == null ? null : BoardPage.tryParse(pageId, json);
}
