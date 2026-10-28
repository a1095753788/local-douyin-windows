import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/folder_item.dart';
import '../data/models/video_item.dart';
import '../providers/folder_provider.dart';
import '../providers/video_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/video_card.dart';

/// 发现：搜索 + 筛选 + 网格浏览
///
/// 手机版没有这一页（屏幕太小）。桌面上一次性把整个库摊开，
/// 想找某个视频不用靠「刷」。
class DiscoverScreen extends StatefulWidget {
  final void Function(VideoItem video) onPlayVideo;

  const DiscoverScreen({super.key, required this.onPlayVideo});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _ctrl = TextEditingController();

  String _keyword = '';
  String? _folderId;
  String _filter = 'all'; // all | unplayed | played | liked | favorited

  List<VideoItem> _results = <VideoItem>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final videos = context.read<VideoProvider>();
    try {
      final list = await videos.search(
        keyword: _keyword,
        folderId: _folderId,
        liked: _filter == 'liked' ? true : null,
        favorited: _filter == 'favorited' ? true : null,
        played: _filter == 'unplayed'
            ? false
            : _filter == 'played'
            ? true
            : null,
      );
      if (!mounted) return;
      setState(() => _results = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = <VideoItem>[]);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<FolderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
          child: Row(
            children: <Widget>[
              const Text(
                '发现',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (v) {
                      _keyword = v;
                      _run();
                    },
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜文件名…',
                      hintStyle: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 17,
                        color: AppTheme.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppTheme.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _FolderFilter(
                folders: folders.folders,
                value: _folderId,
                onChanged: (v) {
                  setState(() => _folderId = v);
                  _run();
                },
              ),
            ],
          ),
        ),

        // 筛选 chips
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Row(
            children: <Widget>[
              for (final f in <MapEntry<String, String>>[
                const MapEntry<String, String>('all', '全部'),
                const MapEntry<String, String>('unplayed', '没看过'),
                const MapEntry<String, String>('played', '看过'),
                const MapEntry<String, String>('liked', '点过赞'),
                const MapEntry<String, String>('favorited', '已收藏'),
              ]) ...<Widget>[
                _FilterChip(
                  label: f.value,
                  active: _filter == f.key,
                  onTap: () {
                    setState(() => _filter = f.key);
                    _run();
                  },
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text(
                _loading ? '搜索中…' : '${_results.length} 条结果',
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppTheme.border),

        Expanded(
          child: _loading
              ? const LoadingState()
              : _results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: '没有匹配的视频',
                  subtitle: '换个关键词，或者把筛选条件放宽一点',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final v = _results[i];
                    return VideoCard(
                      video: v,
                      onTap: () => widget.onPlayVideo(v),
                      onPlay: () => widget.onPlayVideo(v),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.16)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _FolderFilter extends StatelessWidget {
  final List<FolderItem> folders;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FolderFilter({
    required this.folders,
    required this.value,
    required this.onChanged,
  });

  /// DropdownButton 的 value 为 null 时不会匹配任何项，
  /// 会显示成空白，所以用一个哨兵值代表「全部」
  static const String _allSentinel = '__all__';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value ?? _allSentinel,
          isDense: true,
          dropdownColor: AppTheme.surfaceHigh,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
          icon: const Icon(
            Icons.expand_more,
            size: 16,
            color: AppTheme.textTertiary,
          ),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: _allSentinel,
              child: Text('所有文件夹'),
            ),
            for (final f in folders)
              DropdownMenuItem<String?>(
                value: f.id,
                child: SizedBox(
                  width: 150,
                  child: Text(
                    f.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
          onChanged: (v) => onChanged(v == _allSentinel ? null : v),
        ),
      ),
    );
  }
}
