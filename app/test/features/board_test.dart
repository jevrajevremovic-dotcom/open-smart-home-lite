import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/board/board_canvas.dart';
import 'package:open_smart_home_lite/features/board/board_page.dart';
import 'package:open_smart_home_lite/features/board/board_repository.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

/// A valid 1×1 PNG built by hand: signature, IHDR, IDAT, IEND.
Uint8List tinyPng() => Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, //
  0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, //
  31, 21, 196, 137, //
  0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 15, 4, 0, 9, 251, 3, 253,
  227, 85, 242, 156, //
  0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  const page = BoardPage(
    id: 'abc123def456',
    strokes: [
      BoardStroke(
        color: 2,
        width: 9,
        points: [Offset(10, 10), Offset(200, 40)],
      ),
      BoardStroke(color: 0, width: 4, points: [Offset(800, 500)]),
    ],
  );

  test('pages survive the trip through a PNG', () {
    final png = embedBoardData(tinyPng(), page.toJsonString());
    // Still a PNG: our chunk sits after IHDR, IEND stays last.
    expect(png.sublist(0, 8), tinyPng().sublist(0, 8));
    expect(
      png.sublist(png.length - 12),
      tinyPng().sublist(tinyPng().length - 12),
    );
    final back = decodeBoardPng(page.id, png)!;
    expect(back.strokes, hasLength(2));
    expect(back.strokes.first.points.last, const Offset(200, 40));
    expect(back.strokes.first.color, 2);
    expect(decodeBoardPng(page.id, tinyPng()), isNull, reason: 'not ours');

    // The CRC code matches PNG's (IEND's CRC is always AE426082), and our
    // chunk carries the CRC of its type and data.
    expect(boardCrc32('IEND'.codeUnits), 0xAE426082);
    final length = ByteData.sublistView(png, 33, 37).getUint32(0);
    final typeAndData = png.sublist(37, 41 + length);
    expect(
      ByteData.sublistView(png, 41 + length, 45 + length).getUint32(0),
      boardCrc32(typeAndData),
    );
  });

  test('the eraser finds lines near the finger', () {
    final line = page.strokes.first;
    expect(line.hits(const Offset(105, 25), 5), isTrue);
    expect(line.hits(const Offset(105, 120), 5), isFalse);
  });

  test('only our pictures count, newest version per page', () {
    expect(
      BoardImage.fromItem({'id': 'a', 'name': 'osh-board_abc123def456_5.png'}),
      isA<BoardImage>(),
    );
    expect(BoardImage.fromItem({'id': 'b', 'name': 'person.png'}), isNull);
    expect(
      BoardImage.fromItem({'id': 'c', 'name': 'osh-board_../x_5.png'}),
      isNull,
    );
  });

  MockHomeAssistantServer serverOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
          .read(mockHomeAssistantServerProvider);

  // Saving renders a picture, which needs real (not fake) time.
  Future<void> letSave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester, 6);
  }

  testWidgets('draw, save to Home Assistant, undo, live changes', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(900, 1400));
    await settle(tester, 10);
    final server = serverOf(tester);

    await goTo(tester, AppRoutes.todo);
    await settle(tester, 4);
    await tapKey(tester, 'openBoard');
    await settle(tester, 4);
    expect(find.text(en.boardEmpty), findsOneWidget);
    await tapKey(tester, 'boardNewPage');
    await settle(tester, 4);

    final canvas = find.byKey(const Key('boardCanvas'));
    await tester.dragFrom(
      tester.getCenter(canvas) - const Offset(150, 0),
      const Offset(300, 60),
    );
    await letSave(tester);
    expect(server.images, hasLength(1));
    final (item, png) = server.images.values.single;
    expect(item['name'], startsWith('osh-board_'));
    final saved = BoardImage.fromItem(item)!;
    expect(decodeBoardPng(saved.pageId, png)!.strokes, hasLength(1));
    expect(find.text(en.boardSaved), findsOneWidget);

    // A second line, then undo: still one line, the old version replaced.
    await tester.dragFrom(
      tester.getCenter(canvas) + const Offset(0, 80),
      const Offset(200, 0),
    );
    await tapKey(tester, 'boardUndo');
    await letSave(tester);
    expect(server.images, hasLength(1), reason: 'older version deleted');
    final (_, latest) = server.images.values.single;
    expect(decodeBoardPng(saved.pageId, latest)!.strokes, hasLength(1));

    // Another device writes on the same page: it shows up here.
    final elsewhere = embedBoardData(
      tinyPng(),
      BoardPage(
        id: saved.pageId,
        strokes: const [
          BoardStroke(color: 1, width: 4, points: [Offset(1, 1), Offset(9, 9)]),
          BoardStroke(color: 1, width: 4, points: [Offset(5, 1), Offset(9, 3)]),
          BoardStroke(color: 1, width: 4, points: [Offset(7, 1), Offset(9, 5)]),
        ],
      ).toJsonString(),
    );
    server.uploadImage(
      elsewhere,
      BoardImage.fileName(saved.pageId, saved.savedAt + 60000),
    );
    await settle(tester, 6);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester, 4);
    await tapKey(tester, 'boardEraser');
    await settle(tester, 1);
    // Erase across the three short lines in the corner of the page (the
    // page is fitted and centred inside the canvas).
    final area = tester.getRect(canvas);
    final fit = area.width / boardWidth < area.height / boardHeight
        ? area.width / boardWidth
        : area.height / boardHeight;
    final origin =
        area.topLeft +
        Offset(
          (area.width - boardWidth * fit) / 2,
          (area.height - boardHeight * fit) / 2,
        );
    await tester.dragFrom(
      origin + Offset(2 * fit, 2 * fit),
      const Offset(3, 2),
    );
    await letSave(tester);
    final newest = server.images.values
        .map((e) => BoardImage.fromItem(e.$1)!)
        .reduce((a, b) => a.savedAt > b.savedAt ? a : b);
    final strokes = decodeBoardPng(
      saved.pageId,
      server.images[newest.imageId]!.$2,
    )!.strokes;
    debugPrint(
      'IMAGES ${[for (final e in server.images.values) '${e.$1['name']}:${decodeBoardPng('x', e.$2)?.strokes.length}']}',
    );
    expect(strokes.length, lessThan(3), reason: 'loaded, then erased');
    await unmount(tester);
  });

  testWidgets('two fingers zoom in; drawing then lands on the zoomed spot', (
    tester,
  ) async {
    BoardStroke? drawn;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 500,
            child: StatefulBuilder(
              builder: (context, setState) => BoardCanvas(
                strokes: const [],
                tool: BoardTool.pen,
                color: 0,
                width: 4,
                onStroke: (s) => drawn = s,
                onErase: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(BoardCanvas));
    // Pinch out around the centre: ×2.
    final a = await tester.startGesture(center - const Offset(50, 0));
    final b = await tester.startGesture(center + const Offset(50, 0));
    await a.moveTo(center - const Offset(100, 0));
    await b.moveTo(center + const Offset(100, 0));
    await a.up();
    await b.up();
    await tester.pump();
    expect(drawn, isNull, reason: 'two fingers do not draw');

    // 100 screen pixels right of the centre is now 100 page units (×2 zoom
    // of a page fitted at 0.5).
    await tester.dragFrom(center, const Offset(100, 0));
    await tester.pump();
    final pts = drawn!.points;
    expect(pts.first.dx, closeTo(boardWidth / 2, 2));
    expect(pts.last.dx - pts.first.dx, closeTo(100, 3));
  });

  testWidgets('without an administrator, deleting a page explains why', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(900, 1400));
    await settle(tester, 10);
    final server = serverOf(tester)..imageAdmin = false;
    server.uploadImage(
      embedBoardData(
        tinyPng(),
        const BoardPage(id: 'page00000001').toJsonString(),
      ),
      BoardImage.fileName('page00000001', 1),
    );
    await goTo(tester, AppRoutes.board('page00000001'));
    await settle(tester, 6);
    await tapKey(tester, 'boardMenu');
    await settle(tester, 5);
    await tapKey(tester, 'boardDelete');
    await settle(tester, 5);
    await tapKey(tester, 'boardConfirm');
    await settle(tester, 4);
    expect(find.text(en.boardDeleteNeedsAdmin), findsOneWidget);
    expect(server.images, hasLength(1));
    await unmount(tester);
  });
}
