import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/folder_item.dart';
import '../data/models/video_item.dart';
import '../data/repositories/video_repository.dart';
import '../platform/recycle_bin.dart';
import '../providers/folder_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/video_provider.dart';
import '../widgets/app_context_menu.dart';
import '../widgets/empty_state.dart';
import '../widgets/video_card.dart';

/// 文件夹管理
///
/// 左边是文件夹列表，右边是该文件夹下的视频网格。
/// 桌面横向空间够，不用像手机那样点进去再退出来。
class FolderScreen extends StatefulWidget {
  final VoidCallback onAddFolder;
  final void Function(VideoItem video) onPlayVideo;

  const FolderScreen({
    super.key,
    required this.onAddFolder,
    required this.onPlayVideo,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final VideoRepository _repo = VideoRepository();
  String? _selectedId;
  List<VideoItem> _videos = <VideoItem>[];
  bool _loadingVideos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelect());
  }

  void _autoSelect() {
    final folders = context.read<FolderProvider>().folders;
    if (_selectedId == null && folders.isNotEmpty) {
      _select(folders.first.id);
    }
  }

  Future<void> _select(String folderId) async {
    setState(() {
      _selectedId = folderId;
      _loadingVideos = true;
    });
    try {
      final list = await _repo.getByFolder(folderId);
      if (!mounted) return;
      setState(() => _videos = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _videos = <VideoItem>[]);
    }
    if (mounted) setState(() => _loadingVideos = false);
  }

  Future<void> _reloadVideos() async {
    final id = _selectedId;
    if (id == null) return;
    final list = await _repo.getByFolder(id);
    if (!mounted) return;
    setState(() => _videos = list);
  }

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<FolderProvider>();
    final settings = context.watch<SettingsProvider>();

    // 列表变了（新增/删除）后同步选中项
    if (_selectedId == null && folders.folders.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedId == null) _select(folders.folders.first.id);
      });
    }
    FolderItem? selected;
    for (final f in folders.folders) {
      if (f.id == _selectedId) {
        selected = f;
        break;
      }
    }
    // 提成 final 局部变量，闭包里才能安全地做非空提升
    final FolderItem? sel = selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 20, 12),
          child: Row(
            children: <Widget>[
              const Text(
                '文件夹',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${folders.folders.length} 个目录 · ${folders.totalVideos} 个视频',
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (folders.lastScanSummary != null)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    folders.lastScanSummary!,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: folders.scanning
                    ? null
                    : () => folders.scanAll(
                        skipHidden: settings.skipHidden,
                        minFileSizeKb: settings.minFileSizeKb,
                        deepScan: settings.deepScan,
                      ),
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('全部重扫'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.border),
                  textStyle: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: folders.scanning ? null : widget.onAddFolder,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加文件夹'),
              ),
            ],
          ),
        ),

        // ffmpeg 提示
        if (!folders.ffmpegReady) _ffmpegBanner(),

        Expanded(
          child: folders.folders.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: '还没有添加任何文件夹',
                  subtitle:
                      '添加一个目录，会自动递归扫描里面的视频。\n'
                      '支持 39 种容器格式，不需要转码就能直接播。',
                  action: FilledButton.icon(
                    onPressed: widget.onAddFolder,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加文件夹'),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 左：文件夹列表
                    SizedBox(
                      width: 320,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 12, 20),
                        itemCount: folders.folders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final f = folders.folders[i];
                          return _FolderTile(
                            folder: f,
                            selected: f.id == _selectedId,
                            onTap: () => _select(f.id),
                            onScan: () => folders.scanOne(
                              f.id,
                              skipHidden: settings.skipHidden,
                              minFileSizeKb: settings.minFileSizeKb,
                              deepScan: settings.deepScan,
                            ),
                            onToggleAutoScan: () => folders.toggleAutoScan(f),
                            onRename: () => _rename(f, folders),
                            onRemove: () => _remove(f, folders),
                            onReveal: () =>
                                RecycleBin.openContainingFolder(f.path),
                          );
                        },
                      ),
                    ),

                    const VerticalDivider(width: 1, color: AppTheme.border),

                    // 右：视频网格
                    Expanded(
                      child: _loadingVideos
                          ? const LoadingState()
                          : sel == null
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    12,
                                    18,
                                    8,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          sel.path,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.textTertiary,
                                            fontSize: 11.5,
                                            fontFamily: 'Consolas',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${_videos.length} 个视频',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _videos.isEmpty
                                      ? EmptyState(
                                          icon: Icons.videocam_off_outlined,
                                          title: '这个目录里没扫到视频',
                                          subtitle: '确认目录里有视频文件，或者去「我的 → 扫描设置」里打开深度扫描。',
                                          action: FilledButton(
                                            onPressed: () => folders.scanOne(
                                              sel.id,
                                              skipHidden: settings.skipHidden,
                                              minFileSizeKb:
                                                  settings.minFileSizeKb,
                                              deepScan: settings.deepScan,
                                            ),
                                            child: const Text('重新扫描'),
                                          ),
                                        )
                                      : _videoGrid(context, folders),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _videoGrid(BuildContext context, FolderProvider folders) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, i) {
        final v = _videos[i];
        return VideoCard(
          video: v,
          onTap: () => widget.onPlayVideo(v),
          onPlay: () => widget.onPlayVideo(v),
          onDelete: () => _deleteVideo(v, folders),
        );
      },
    );
  }

  Widget _ffmpegBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.favorite.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.favorite.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.favorite),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '没找到 ffmpeg：视频照样能播（libmpv 自带解码器），但不会生成缩略图、也读不到时长。'
              '把 ffmpeg.exe 放到程序目录下的 ffmpeg\\ 文件夹里即可。',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(FolderItem f, FolderProvider folders) async {
    final ctrl = TextEditingController(text: f.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: const InputDecoration(hintText: '显示名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await folders.renameFolder(f.id, ctrl.text.trim());
    }
    ctrl.dispose();
  }

  Future<void> _remove(FolderItem f, FolderProvider folders) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '移除「${f.displayName}」',
          style: const TextStyle(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '这个目录下有 ${f.videoCount} 个视频记录。\n'
              '${f.path}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '磁盘上的文件不会被移动，除非你选第三项。',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11.5),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('record'),
            child: const Text('只移除记录'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('files'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('连文件一起删（回收站）'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    if (!mounted) return;
    final deleteFiles = choice == 'files';
    if (deleteFiles) {
      final ok = await confirmDialog(
        context,
        title: '确认删除文件？',
        message:
            '将把「${f.displayName}」下的 ${f.videoCount} 个视频文件移到回收站。'
            '目录本身和里面的其他文件不会动。',
        confirmText: '移到回收站',
        danger: true,
      );
      if (!ok) return;
    }
    await folders.removeFolder(f.id, deleteFiles: deleteFiles);
    if (mounted) {
      setState(() {
        _selectedId = null;
        _videos = <VideoItem>[];
      });
      _autoSelect();
    }
  }

  Future<void> _deleteVideo(VideoItem v, FolderProvider folders) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条视频', style: TextStyle(fontSize: 15)),
        content: Text(
          v.name,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('record'),
            child: const Text('只移除记录'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('file'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('移到回收站'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await folders.deleteVideo(
      v,
      deleteFile: choice == 'file',
      toRecycleBin: true,
    );
    await _reloadVideos();
    if (mounted) context.read<VideoProvider>().onLibraryChanged();
  }
}

class _FolderTile extends StatefulWidget {
  final FolderItem folder;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onScan;
  final VoidCallback onToggleAutoScan;
  final VoidCallback onRename;
  final VoidCallback onRemove;
  final VoidCallback onReveal;

  const _FolderTile({
    required this.folder,
    required this.selected,
    required this.onTap,
    required this.onScan,
    required this.onToggleAutoScan,
    required this.onRename,
    required this.onRemove,
    required this.onReveal,
  });

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.folder;
    final missing = !f.available;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (d) => _contextMenu(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : _hover
                ? Colors.white.withValues(alpha: 0.04)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : AppTheme.border,
              width: 0.5,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                missing ? Icons.folder_off_outlined : Icons.folder_rounded,
                size: 18,
                color: missing
                    ? AppTheme.danger.withValues(alpha: 0.7)
                    : AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            f.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: missing
                                  ? AppTheme.textTertiary
                                  : AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (f.autoScan) ...<Widget>[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: '自动监视新文件',
                            child: Icon(
                              Icons.sync,
                              size: 11,
                              color: AppTheme.success.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missing
                          ? '路径不存在，可能移动硬盘没插'
                          : '${f.videoCount} 个视频 · ${_scannedText(f.lastScannedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: missing
                            ? AppTheme.danger.withValues(alpha: 0.75)
                            : AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hover)
                PopupMenuButton<String>(
                  tooltip: '更多',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppTheme.textTertiary,
                  ),
                  onSelected: (v) {
                    switch (v) {
                      case 'scan':
                        widget.onScan();
                        break;
                      case 'auto':
                        widget.onToggleAutoScan();
                        break;
                      case 'rename':
                        widget.onRename();
                        break;
                      case 'reveal':
                        widget.onReveal();
                        break;
                      case 'remove':
                        widget.onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'scan',
                      height: 34,
                      child: Text('立即扫描', style: TextStyle(fontSize: 12.5)),
                    ),
                    PopupMenuItem<String>(
                      value: 'auto',
                      height: 34,
                      child: Text(
                        f.autoScan ? '关闭自动监视' : '开启自动监视',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'rename',
                      height: 34,
                      child: Text('重命名显示名', style: TextStyle(fontSize: 12.5)),
                    ),
                    const PopupMenuItem<String>(
                      value: 'reveal',
                      height: 34,
                      child: Text(
                        '在资源管理器中打开',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const PopupMenuDivider(height: 6),
                    const PopupMenuItem<String>(
                      value: 'remove',
                      height: 34,
                      child: Text(
                        '移除文件夹',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(width: 26),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contextMenu(Offset pos) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final r = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx, pos.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      color: AppTheme.surfaceHigh,
      items: const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'scan', height: 34, child: Text('立即扫描')),
        PopupMenuItem<String>(
          value: 'reveal',
          height: 34,
          child: Text('在资源管理器中打开'),
        ),
        PopupMenuItem<String>(value: 'rename', height: 34, child: Text('重命名')),
        PopupMenuDivider(height: 6),
        PopupMenuItem<String>(
          value: 'remove',
          height: 34,
          child: Text('移除', style: TextStyle(color: AppTheme.danger)),
        ),
      ],
    );
    switch (r) {
      case 'scan':
        widget.onScan();
        break;
      case 'reveal':
        widget.onReveal();
        break;
      case 'rename':
        widget.onRename();
        break;
      case 'remove':
        widget.onRemove();
        break;
    }
  }

  static String _scannedText(int ms) {
    if (ms <= 0) return '从未扫描';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '刚刚扫描';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前扫描';
    if (diff.inDays < 1) return '${diff.inHours} 小时前扫描';
    if (diff.inDays < 30) return '${diff.inDays} 天前扫描';
    return '很久没扫了';
  }
}
