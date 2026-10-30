import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_log.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../data/models/video_item.dart';
import '../providers/comment_provider.dart';
import '../providers/folder_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/video_provider.dart';
import '../widgets/app_context_menu.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_banner.dart';
import 'discover_screen.dart';
import 'folder_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// 应用外壳：侧边栏 + 四个页面 + 全局快捷键
///
/// 「当前在播哪一条」只在这里决策一次，其他 widget 都是纯展示。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  int _page = 0;

  // 首页两个 tab：0 推荐，1 收藏
  int _tab = 0;
  int _favIndex = 0;

  bool _collapsed = false;
  bool _showInfo = false;
  bool _showComments = false;
  bool _danmakuOn = true;
  bool _fullScreen = false;

  bool _booting = true;
  String? _bootError;

  final FocusNode _focus = FocusNode(debugLabel: 'app-shell');

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // ignore: discarded_futures
    _bootstrap();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _focus.dispose();
    super.dispose();
  }

  // ────────────────────── 启动 ──────────────────────

  Future<void> _bootstrap() async {
    final settings = context.read<SettingsProvider>();
    final player = context.read<PlayerProvider>();
    final folders = context.read<FolderProvider>();
    final videos = context.read<VideoProvider>();
    final comments = context.read<CommentProvider>();

    _danmakuOn = settings.danmakuEnabled;

    try {
      await player.init(
        mode: settings.hwdecMode,
        completion: settings.completionBehavior,
        speed: settings.defaultSpeed,
        volume: settings.volume,
      );

      player.onAutoNext = () => _goNext();
      player.onVideoChanged = (id) => videos.onPlayCounted(id);

      folders.onLibraryChanged = () async {
        await videos.onLibraryChanged();
      };
      comments.onCountChanged = (vid, delta) =>
          videos.bumpCommentCount(vid, delta);

      await folders.load();
      folders.setWatchEnabled(settings.watchEnabled);

      // 先把指向空气的记录清掉，否则推荐流会刷到打不开的文件
      final pruned = await folders.pruneMissing();
      AppLog.w(
        'boot',
        'ffmpegReady=${folders.ffmpegReady} '
            'folders=${folders.folders.length} pruned=$pruned',
      );

      // 上次退出时可能还有没补完的缩略图，后台接着补
      if (folders.ffmpegReady) {
        unawaited(folders.generateMissingThumbnails());
      }

      await videos.loadStats();
      await videos.loadFeed();
      await videos.loadFavorites();
    } catch (e) {
      _bootError = e.toString();
    }

    if (!mounted) return;
    setState(() => _booting = false);
    await _playCurrent();
    if (mounted) _focus.requestFocus();
  }

  // ────────────────────── 当前播放的是哪一条 ──────────────────────

  List<VideoItem> get _activeList {
    final videos = context.read<VideoProvider>();
    return _tab == 0 ? videos.feed : videos.favorites;
  }

  int get _activeIndex {
    final videos = context.read<VideoProvider>();
    return _tab == 0 ? videos.index : _favIndex;
  }

  VideoItem? get _activeVideo {
    final list = _activeList;
    final i = _activeIndex;
    if (i < 0 || i >= list.length) return null;
    return list[i];
  }

  Future<void> _playCurrent() async {
    final player = context.read<PlayerProvider>();
    final comments = context.read<CommentProvider>();
    final videos = context.read<VideoProvider>();

    // 收藏页取消收藏后列表会变短，索引可能越界
    if (_tab == 1) {
      final n = videos.favorites.length;
      if (_favIndex > n - 1) _favIndex = n <= 0 ? 0 : n - 1;
    }

    final v = _activeVideo;
    if (v == null) {
      await player.stop();
      comments.clear();
      return;
    }
    await comments.load(v.id);
    await player.open(v);
  }

  void _goNext() {
    final videos = context.read<VideoProvider>();
    if (_tab == 0) {
      if (videos.index >= videos.feedLength - 3) videos.appendMore();
      if (videos.next()) {
        _playCurrent();
      }
    } else {
      if (_favIndex < videos.favorites.length - 1) {
        setState(() => _favIndex++);
        _playCurrent();
      }
    }
  }

  void _goPrev() {
    final videos = context.read<VideoProvider>();
    if (_tab == 0) {
      if (videos.prev()) _playCurrent();
    } else {
      if (_favIndex > 0) {
        setState(() => _favIndex--);
        _playCurrent();
      }
    }
  }

  void _switchTab(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _favIndex = 0;
    });
    if (tab == 1) {
      // ignore: discarded_futures
      context.read<VideoProvider>().loadFavorites().then((_) {
        if (mounted) _playCurrent();
      });
    } else {
      _playCurrent();
    }
  }

  /// 从收藏页/发现页/文件夹页点了一条视频 → 立刻播
  Future<void> _playSpecific(VideoItem v) async {
    final videos = context.read<VideoProvider>();
    final favorites = videos.favorites;
    final fi = favorites.indexWhere((e) => e.id == v.id);
    if (fi >= 0) {
      setState(() {
        _tab = 1;
        _favIndex = fi;
        _page = 0;
      });
      await _playCurrent();
      return;
    }
    final ri = videos.feed.indexWhere((e) => e.id == v.id);
    if (ri >= 0) {
      setState(() {
        _tab = 0;
        _page = 0;
      });
      videos.jumpTo(ri);
      await _playCurrent();
      return;
    }
    // 推荐流里没有（比如被排除的收藏），直接开播
    final player = context.read<PlayerProvider>();
    final comments = context.read<CommentProvider>();
    setState(() {
      _page = 0;
      _tab = 0;
    });
    await comments.load(v.id);
    await player.open(v);
  }

  // ────────────────────── 右键 / 侧栏动作 ──────────────────────

  Future<void> _handleAction(VideoMenuAction action, VideoItem v) async {
    final player = context.read<PlayerProvider>();
    final videos = context.read<VideoProvider>();
    final folders = context.read<FolderProvider>();

    switch (action) {
      case VideoMenuAction.playPause:
        await player.playPause();
        break;

      case VideoMenuAction.like:
        await videos.toggleLike(v.id);
        await _playCurrent();
        break;

      case VideoMenuAction.favorite:
        await videos.toggleFavorite(v.id);
        // 取消收藏后当前流里可能就没有它了，重新定位
        await _playCurrent();
        break;

      case VideoMenuAction.notInterested:
        await videos.markNotInterested(v.id);
        if (videos.index >= videos.feedLength) {
          videos.jumpTo(videos.feedLength - 1);
        }
        await _playCurrent();
        _toast('已标记不感兴趣，可以在「我的」里一键恢复');
        break;

      case VideoMenuAction.comment:
        setState(() {
          _showComments = !_showComments;
          if (_showComments) _showInfo = false;
        });
        break;

      case VideoMenuAction.info:
        setState(() {
          _showInfo = !_showInfo;
          if (_showInfo) _showComments = false;
        });
        break;

      case VideoMenuAction.revealInExplorer:
        await _reveal(v.path);
        break;

      case VideoMenuAction.openExternal:
        await _openExternal(v.path);
        break;

      case VideoMenuAction.copyPath:
        await Clipboard.setData(ClipboardData(text: v.path));
        _toast('路径已复制');
        break;

      case VideoMenuAction.deleteRecord:
        final ok = await confirmDialog(
          context,
          title: '从库里移除？',
          message: '只删掉这条记录，磁盘上的文件不会动。\n${v.name}',
          confirmText: '移除',
        );
        if (!ok) return;
        await folders.deleteVideo(v, deleteFile: false);
        videos.removeFromFeed(v.id);
        await _playCurrent();
        break;

      case VideoMenuAction.deleteToRecycleBin:
        final ok = await confirmDialog(
          context,
          title: '移到回收站？',
          message: '文件会进回收站，可以从回收站还原。\n${v.path}',
          confirmText: '移到回收站',
          danger: true,
        );
        if (!ok) return;
        await folders.deleteVideo(v, deleteFile: true, toRecycleBin: true);
        videos.removeFromFeed(v.id);
        await _playCurrent();
        break;
    }
  }

  Future<void> _reveal(String path) async {
    try {
      await Process.run('explorer.exe', <String>['/select,', path]);
    } catch (_) {}
  }

  Future<void> _openExternal(String path) async {
    try {
      await Process.run('rundll32.exe', <String>[
        'url.dll,FileProtocolHandler',
        path,
      ]);
    } catch (_) {}
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          width: 420,
        ),
      );
  }

  // ────────────────────── 文件夹 ──────────────────────

  Future<void> _addFolder() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: '选择放视频的文件夹');
    if (path == null || path.isEmpty) return;
    if (!mounted) return;

    final folders = context.read<FolderProvider>();
    final settings = context.read<SettingsProvider>();
    final videos = context.read<VideoProvider>();
    try {
      await folders.addFolder(path);
      await videos.onLibraryChanged();
      await videos.loadFeed();
      await _playCurrent();
      if (mounted) _toast(folders.lastScanSummary ?? '已添加');
    } catch (e) {
      _toast('$e');
    }
    // 深度扫描设置要跟着走
    if (settings.deepScan) {
      await folders.scanAll(
        skipHidden: settings.skipHidden,
        minFileSizeKb: settings.minFileSizeKb,
        deepScan: true,
      );
      await videos.onLibraryChanged();
    }
  }

  Future<void> _rescan() async {
    final folders = context.read<FolderProvider>();
    final settings = context.read<SettingsProvider>();
    final videos = context.read<VideoProvider>();
    await folders.scanAll(
      skipHidden: settings.skipHidden,
      minFileSizeKb: settings.minFileSizeKb,
      deepScan: settings.deepScan,
    );
    await videos.onLibraryChanged();
    if (mounted) _toast(folders.lastScanSummary ?? '扫描完成');
  }

  Future<void> _reshuffle() async {
    final videos = context.read<VideoProvider>();
    await videos.loadFeed();
    if (_tab == 0) await _playCurrent();
    if (mounted) _toast('推荐已重新洗牌');
  }

  // ────────────────────── 全屏 ──────────────────────

  Future<void> _toggleFullScreen() async {
    final entering = !_fullScreen;
    _fullScreen = entering;

    if (entering) {
      // 全屏是「专心看视频」的语义：切回首页、把侧栏面板关掉，
      // 否则屏幕铺满了却还有东西挡着
      setState(() {
        _page = 0;
        _showInfo = false;
        _showComments = false;
      });
    }

    await windowManager.setFullScreen(_fullScreen);
    if (mounted) setState(() {});
  }

  // ────────────────────── 键盘 ──────────────────────

  bool _isTyping() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;

    // Ctrl 组合键即使正在输入也要生效
    if (ctrl) {
      if (key == LogicalKeyboardKey.keyO) {
        _addFolder();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyR) {
        _rescan();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (alt) return KeyEventResult.ignored;
    if (_isTyping()) return KeyEventResult.ignored;

    final player = context.read<PlayerProvider>();
    final settings = context.read<SettingsProvider>();
    final v = _activeVideo;

    if (key == LogicalKeyboardKey.f11) {
      _toggleFullScreen();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      // 全屏时 Esc 先退全屏，顺手把面板也关掉
      if (_fullScreen) {
        setState(() {
          _showComments = false;
          _showInfo = false;
        });
        _toggleFullScreen();
        return KeyEventResult.handled;
      }
      if (_showComments || _showInfo) {
        setState(() {
          _showComments = false;
          _showInfo = false;
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 只在首页响应播放类快捷键
    if (_page != 0) {
      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.digit4) {
        final i = <LogicalKeyboardKey>[
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit3,
          LogicalKeyboardKey.digit4,
        ].indexOf(key);
        setState(() => _page = i);
        if (settings.pauseOnPageChange) player.pause();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    switch (key) {
      case LogicalKeyboardKey.space:
        player.playPause();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyJ:
        _goNext();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyK:
        _goPrev();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
        player.seekRelative(-10);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        player.seekRelative(10);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.tab:
        setState(() {
          _showInfo = !_showInfo;
          if (_showInfo) _showComments = false;
        });
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyL:
        if (v != null) _handleAction(VideoMenuAction.like, v);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyF:
        if (v != null) _handleAction(VideoMenuAction.favorite, v);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyI:
        if (v != null) _handleAction(VideoMenuAction.notInterested, v);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyC:
        setState(() {
          _showComments = !_showComments;
          if (_showComments) _showInfo = false;
        });
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyD:
        setState(() => _danmakuOn = !_danmakuOn);
        settings.setDanmakuEnabled(_danmakuOn);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyM:
        player.toggleMute();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.bracketLeft:
        player.nudgeSpeed(-AppConstants.speedStep);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.bracketRight:
        player.nudgeSpeed(AppConstants.speedStep);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.digit1:
      case LogicalKeyboardKey.digit2:
      case LogicalKeyboardKey.digit3:
      case LogicalKeyboardKey.digit4:
      case LogicalKeyboardKey.digit5:
      case LogicalKeyboardKey.digit6:
        final presets = AppConstants.speedPresets;
        final idx = <LogicalKeyboardKey>[
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit3,
          LogicalKeyboardKey.digit4,
          LogicalKeyboardKey.digit5,
          LogicalKeyboardKey.digit6,
        ].indexOf(key);
        if (idx >= 0 && idx < presets.length) {
          player.setSpeed(presets[idx]);
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  // ────────────────────── 窗口事件 ──────────────────────

  @override
  void onWindowBlur() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (settings.pauseOnBlur) {
      context.read<PlayerProvider>().pause();
    }
  }

  @override
  void onWindowFocus() {
    if (mounted) _focus.requestFocus();
  }

  @override
  void onWindowClose() {
    // 关窗前把播放进度、缩略图目录等写回磁盘
    final player = context.read<PlayerProvider>();
    player.leave().whenComplete(() async {
      await windowManager.destroy();
    });
  }

  // ────────────────────── 构建 ──────────────────────

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<FolderProvider>();

    if (_booting) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: LoadingState(text: '正在准备…'),
      );
    }

    if (_bootError != null) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: EmptyState(
          icon: Icons.error_outline,
          title: '启动失败',
          subtitle: _bootError,
          action: FilledButton(
            onPressed: () => setState(() {
              _bootError = null;
              _booting = true;
            }),
            child: const Text('重试'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Row(
          children: <Widget>[
            // 全屏时侧边栏整个不要，画面才能铺满
            if (!_fullScreen) ...<Widget>[
              _Sidebar(
                page: _page,
                collapsed: _collapsed,
                onPage: (i) {
                  if (i == _page) return;
                  setState(() => _page = i);
                  final settings = context.read<SettingsProvider>();
                  if (settings.pauseOnPageChange) {
                    context.read<PlayerProvider>().pause();
                  }
                  _focus.requestFocus();
                },
                onToggleCollapse: () =>
                    setState(() => _collapsed = !_collapsed),
              ),
              const VerticalDivider(width: 1, color: AppTheme.border),
            ],
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: _buildPage()),
                  if (!_fullScreen)
                    ScanBanner(folders: folders, onCancel: folders.cancelScan),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() {
    return IndexedStack(
      index: _page,
      children: <Widget>[
        _buildHome(),
        FolderScreen(onAddFolder: _addFolder, onPlayVideo: _playSpecific),
        DiscoverScreen(onPlayVideo: _playSpecific),
        ProfileScreen(
          onLibraryReset: () async {
            await context.read<VideoProvider>().loadFeed();
            await _playCurrent();
          },
        ),
      ],
    );
  }

  Widget _buildHome() {
    final videos = context.watch<VideoProvider>();
    final v = _activeVideo;
    final list = _activeList;
    final idx = _activeIndex;

    if (videos.feed.isEmpty && _tab == 0 && !videos.loading) {
      return EmptyState(
        icon: Icons.video_library_outlined,
        title: '还没有视频可以刷',
        subtitle:
            '添加一个放视频的文件夹，会自动递归扫描。\n'
            '支持 mp4 / mkv / avi / rmvb / m2ts / vob 等 39 种容器，不用转码。',
        action: FilledButton.icon(
          onPressed: _addFolder,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加文件夹'),
        ),
      );
    }

    return HomeScreen(
      tab: _tab,
      onTab: _switchTab,
      video: v,
      index: idx,
      length: list.length,
      showInfo: _showInfo,
      showComments: _showComments,
      danmakuOn: _danmakuOn,
      onToggleInfo: () => setState(() {
        _showInfo = !_showInfo;
        if (_showInfo) _showComments = false;
      }),
      onToggleComments: () => setState(() {
        _showComments = !_showComments;
        if (_showComments) _showInfo = false;
      }),
      onToggleDanmaku: () {
        setState(() => _danmakuOn = !_danmakuOn);
        context.read<SettingsProvider>().setDanmakuEnabled(_danmakuOn);
      },
      onPlayPause: () => context.read<PlayerProvider>().playPause(),
      onNext: _goNext,
      onPrev: _goPrev,
      onAddFolder: _addFolder,
      onRefresh: _reshuffle,
      onCloseInfo: () => setState(() => _showInfo = false),
      onCloseComments: () => setState(() => _showComments = false),
      onFullscreen: _toggleFullScreen,
      immersive: _fullScreen,
      onAction: _handleAction,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int page;
  final bool collapsed;
  final ValueChanged<int> onPage;
  final VoidCallback onToggleCollapse;

  const _Sidebar({
    required this.page,
    required this.collapsed,
    required this.onPage,
    required this.onToggleCollapse,
  });

  static const List<({IconData icon, String label})> _items =
      <({IconData icon, String label})>[
        (icon: Icons.play_circle_outline, label: '首页'),
        (icon: Icons.folder_outlined, label: '文件夹'),
        (icon: Icons.explore_outlined, label: '发现'),
        (icon: Icons.person_outline, label: '我的'),
      ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      width: collapsed
          ? AppConstants.sidebarCollapsedWidth
          : AppConstants.sidebarWidth,
      color: AppTheme.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Logo
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 14 : 18, 18, 14, 22),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFFE2C55), Color(0xFFFF6B81)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (!collapsed) ...<Widget>[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '本地抖音',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          for (var i = 0; i < _items.length; i++)
            _NavItem(
              icon: _items[i].icon,
              label: _items[i].label,
              collapsed: collapsed,
              selected: page == i,
              onTap: () => onPage(i),
            ),

          const Spacer(),

          // 折叠
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Tooltip(
              message: collapsed ? '展开侧栏' : '收起侧栏',
              child: InkWell(
                onTap: onToggleCollapse,
                borderRadius: BorderRadius.circular(7),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right
                        : Icons.keyboard_double_arrow_left,
                    size: 17,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    final content = Container(
      margin: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 10 : 12,
        vertical: 2,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 10 : 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.14)
            : _hover
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            widget.icon,
            size: 19,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
          ),
          if (!widget.collapsed) ...<Widget>[
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: widget.collapsed
            ? Tooltip(message: widget.label, child: content)
            : content,
      ),
    );
  }
}
