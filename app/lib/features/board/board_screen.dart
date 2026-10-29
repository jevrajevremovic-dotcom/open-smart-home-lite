import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../../core/errors/app_failure.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/status_widgets.dart';
import 'board_canvas.dart';
import 'board_page.dart';
import 'board_repository.dart';

/// All pages of the board, newest first.
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pages = ref.watch(boardPagesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.boardTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boardNewPage'),
        onPressed: () => context.push(
          AppRoutes.board(
            BoardRepository.newPageId(),
            kiosk: ref.read(kioskActiveProvider),
          ),
        ),
        icon: const Icon(Icons.draw_outlined),
        label: Text(l10n.boardNewPage),
      ),
      body: MockModeBanner(
        child: switch (pages) {
          AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (value.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    l10n.boardEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final columns = (c.maxWidth / 320).floor().clamp(1, 4);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final page in value)
                          SizedBox(
                            width: (c.maxWidth - 12 * (columns - 1)) / columns,
                            child: BoardPageCard(
                              image: page,
                              kiosk: ref.watch(kioskActiveProvider),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(
                l10n.boardStorageNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AsyncError() => Padding(
            padding: const EdgeInsets.all(16),
            child: InlineNotice.warning(l10n.boardUnavailable),
          ),
          _ => ListSkeleton(rows: 3, label: l10n.loadingContent),
        },
      ),
    );
  }
}

/// A page as a card: its drawing and when it was last changed.
class BoardPageCard extends ConsumerWidget {
  const BoardPageCard({super.key, required this.image, this.kiosk = false});

  final BoardImage image;
  final bool kiosk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final content = ref.watch(boardContentProvider(image));
    final saved = DateTime.fromMillisecondsSinceEpoch(image.savedAt);
    return Card(
      key: ValueKey('boardPage-${image.pageId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.board(image.pageId, kiosk: kiosk)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (content) {
              AsyncData(:final value) => BoardThumbnail(page: value),
              _ => const AspectRatio(
                aspectRatio: boardWidth / boardHeight,
                child: Shimmer(child: SkeletonBox(radius: 0)),
              ),
            },
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                DateFormat.MMMd(l10n.localeName).add_Hm().format(saved),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draw and write on one page. Saved to Home Assistant shortly after each
/// change and when leaving; changes made on another device load live.
class BoardEditorScreen extends ConsumerStatefulWidget {
  const BoardEditorScreen({super.key, required this.pageId});

  final String pageId;

  @override
  ConsumerState<BoardEditorScreen> createState() => _BoardEditorScreenState();
}

enum _SaveState { idle, saving, saved, failed }

class _BoardEditorScreenState extends ConsumerState<BoardEditorScreen> {
  List<BoardStroke> _strokes = const [];
  final List<List<BoardStroke>> _undo = [];
  final List<List<BoardStroke>> _redo = [];
  BoardTool _tool = BoardTool.pen;
  int _color = 0;
  int _width = 0;

  /// Image the current strokes are based on (`null`: a new page).
  String? _base;
  bool _loaded = false;
  bool _dirty = false;
  String? _changedElsewhere;
  _SaveState _save = _SaveState.idle;
  Timer? _timer;
  late final BoardRepository _repository = ref.read(boardRepositoryProvider);

  BoardImage? get _latest => ref
      .read(boardPagesProvider)
      .value
      ?.where((p) => p.pageId == widget.pageId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load([BoardImage? image]) async {
    final latest = image ?? _latest;
    if (latest == null) {
      // A new page (or the list is still loading): start empty.
      setState(() => _loaded = true);
      return;
    }
    try {
      final page = await ref.read(boardContentProvider(latest).future);
      if (!mounted) return;
      setState(() {
        _strokes = page.strokes;
        _base = latest.imageId;
        _loaded = true;
        _dirty = false;
        _changedElsewhere = null;
        _undo.clear();
        _redo.clear();
      });
    } on AppFailure {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _change(List<BoardStroke> next) {
    setState(() {
      _undo.add(_strokes);
      _redo.clear();
      _strokes = next;
      _dirty = true;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), _saveNow);
  }

  Future<void> _saveNow() async {
    _timer?.cancel();
    if (!_dirty) return;
    final page = BoardPage(id: widget.pageId, strokes: _strokes);
    if (mounted) setState(() => _save = _SaveState.saving);
    _dirty = false;
    try {
      final saved = await _repository.save(page);
      _base = saved.imageId;
      if (mounted) setState(() => _save = _SaveState.saved);
    } on Object {
      _dirty = true;
      if (!mounted) return;
      setState(() => _save = _SaveState.failed);
      _timer = Timer(const Duration(seconds: 10), _saveNow);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_dirty) {
      // Leaving with unsaved lines: save in the background.
      unawaited(
        _repository
            .save(BoardPage(id: widget.pageId, strokes: _strokes))
            .then((_) {}, onError: (Object _) {}),
      );
    }
    super.dispose();
  }

  Future<bool> _confirm(String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('boardConfirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _deletePage() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(l10n.boardDeleteConfirm, l10n.delete)) return;
    try {
      _timer?.cancel();
      _dirty = false;
      await _repository.deletePage(widget.pageId);
      if (mounted) context.pop();
    } on AppFailure {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.boardDeleteNeedsAdmin)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    // Another device saved this page: load it, unless we are mid-edit.
    ref.listen(boardPagesProvider, (_, next) {
      final latest = next.value
          ?.where((p) => p.pageId == widget.pageId)
          .firstOrNull;
      if (latest == null ||
          latest.imageId == _base ||
          _repository.ownImages.contains(latest.imageId)) {
        return;
      }
      if (!_loaded || (!_dirty && _save != _SaveState.saving)) {
        unawaited(_load(latest));
      } else {
        setState(() => _changedElsewhere = latest.imageId);
      }
    });

    final status = switch (_save) {
      _SaveState.saving => l10n.boardSaving,
      _SaveState.saved => l10n.boardSaved,
      _SaveState.failed => l10n.boardSaveFailed,
      _SaveState.idle => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.boardTitle),
        actions: [
          if (status != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  status,
                  key: const Key('boardSaveState'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _save == _SaveState.failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            key: const Key('boardMenu'),
            onSelected: (v) async {
              if (v == 'clear' &&
                  await _confirm(l10n.boardClearConfirm, l10n.boardClear)) {
                _change(const []);
              } else if (v == 'delete') {
                await _deletePage();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('boardClear'),
                value: 'clear',
                child: Text(l10n.boardClear),
              ),
              PopupMenuItem(
                key: const Key('boardDelete'),
                value: 'delete',
                child: Text(l10n.boardDeletePage),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_changedElsewhere != null)
            MaterialBanner(
              content: Text(l10n.boardChangedElsewhere),
              actions: [
                TextButton(
                  key: const Key('boardReload'),
                  onPressed: () => _load(),
                  child: Text(l10n.boardReload),
                ),
              ],
            ),
          if (MediaQuery.sizeOf(context).aspectRatio < 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.boardZoomHint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: BoardCanvas(
                      strokes: _strokes,
                      tool: _tool,
                      color: _color,
                      width: boardWidths[_width],
                      onStroke: (s) => _change([..._strokes, s]),
                      onErase: (hit) => _change([
                        for (var i = 0; i < _strokes.length; i++)
                          if (!hit.contains(i)) _strokes[i],
                      ]),
                    ),
                  ),
          ),
          _Toolbar(
            tool: _tool,
            color: _color,
            width: _width,
            canUndo: _undo.isNotEmpty,
            canRedo: _redo.isNotEmpty,
            onTool: (t) => setState(() => _tool = t),
            onColor: (c) => setState(() {
              _color = c;
              _tool = BoardTool.pen;
            }),
            onWidth: (w) => setState(() {
              _width = w;
              _tool = BoardTool.pen;
            }),
            onUndo: () {
              setState(() {
                _redo.add(_strokes);
                _strokes = _undo.removeLast();
                _dirty = true;
              });
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 1500), _saveNow);
            },
            onRedo: () => _change(_redo.removeLast()),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.tool,
    required this.color,
    required this.width,
    required this.canUndo,
    required this.canRedo,
    required this.onTool,
    required this.onColor,
    required this.onWidth,
    required this.onUndo,
    required this.onRedo,
  });

  final BoardTool tool;
  final int color;
  final int width;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<BoardTool> onTool;
  final ValueChanged<int> onColor;
  final ValueChanged<int> onWidth;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          // Wraps to two rows on phones instead of hiding tools off-screen.
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < boardColors.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: IconButton(
                    key: ValueKey('boardColor-$i'),
                    tooltip: l10n.boardColor(i + 1),
                    isSelected: tool == BoardTool.pen && color == i,
                    onPressed: () => onColor(i),
                    icon: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: i == 0 && dark ? boardInkOnDark : boardColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tool == BoardTool.pen && color == i
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: tool == BoardTool.pen && color == i ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              for (var i = 0; i < boardWidths.length; i++)
                IconButton(
                  key: ValueKey('boardWidth-$i'),
                  tooltip: l10n.boardWidth(i + 1),
                  isSelected: tool == BoardTool.pen && width == i,
                  style: IconButton.styleFrom(
                    backgroundColor: tool == BoardTool.pen && width == i
                        ? theme.colorScheme.secondaryContainer
                        : null,
                  ),
                  onPressed: () => onWidth(i),
                  icon: Container(
                    width: 6.0 + i * 6,
                    height: 6.0 + i * 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('boardEraser'),
                tooltip: l10n.boardEraser,
                isSelected: tool == BoardTool.eraser,
                style: IconButton.styleFrom(
                  backgroundColor: tool == BoardTool.eraser
                      ? theme.colorScheme.secondaryContainer
                      : null,
                ),
                onPressed: () => onTool(
                  tool == BoardTool.eraser ? BoardTool.pen : BoardTool.eraser,
                ),
                icon: const Icon(Icons.auto_fix_normal_outlined),
              ),
              IconButton(
                key: const Key('boardUndo'),
                tooltip: l10n.boardUndo,
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const Key('boardRedo'),
                tooltip: l10n.boardRedo,
                onPressed: canRedo ? onRedo : null,
                icon: const Icon(Icons.redo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
