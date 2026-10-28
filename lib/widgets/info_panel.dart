import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../data/models/video_item.dart';

/// 右侧信息面板
///
/// 手机版没有这个（屏幕太小放不下）。桌面上把「这条视频到底是什么」
/// 一次全摊开：文件属性、播放统计、容器/编码/实际解码器。
class InfoPanel extends StatelessWidget {
  final VideoItem? video;
  final String container;
  final String codec;
  final String hwdecActual;
  final Duration position;
  final Duration duration;
  final double speed;
  final VoidCallback onClose;

  const InfoPanel({
    super.key,
    required this.video,
    required this.onClose,
    this.container = '',
    this.codec = '',
    this.hwdecActual = '',
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final v = video;

    return Container(
      width: AppConstants.infoPanelWidth,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: <Widget>[
                const Text(
                  '视频信息',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  iconSize: 18,
                  tooltip: '关闭  (Tab)',
                  icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: v == null
                ? const Center(
                    child: Text(
                      '没有正在播放的视频',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: <Widget>[
                      Text(
                        v.displayName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _Section('文件', <_Row>[
                        _Row('文件名', v.name, copyable: true),
                        _Row('路径', v.path, copyable: true, mono: true),
                        _Row(
                          '所在文件夹',
                          v.folderName.isEmpty ? '-' : v.folderName,
                        ),
                        _Row('大小', v.fileSizeFormatted),
                        _Row('格式', v.extension.toUpperCase()),
                        _Row('分辨率', v.resolution.isEmpty ? '-' : v.resolution),
                        _Row(
                          '时长',
                          v.durationText.isEmpty ? '-' : v.durationText,
                        ),
                        _Row(
                          '修改时间',
                          v.fileMtime > 0 ? _fmtDate(v.fileMtime) : '-',
                        ),
                      ]),

                      _Section('解码', <_Row>[
                        _Row('容器', container.isEmpty ? '-' : container),
                        _Row('视频编码', codec.isEmpty ? '-' : codec),
                        _Row(
                          '实际解码器',
                          hwdecActual.isEmpty ? '-' : hwdecActual,
                          highlight: true,
                          hint: hwdecActual == 'no' ? '软解回落' : null,
                        ),
                        _Row(
                          '播放位置',
                          '${_fmtDuration(position)} / ${_fmtDuration(duration)}',
                        ),
                        _Row('倍速', '${speed.toStringAsFixed(2)}x'),
                      ]),

                      _Section('观看统计', <_Row>[
                        _Row('播放次数', '${v.playCount}'),
                        _Row('点赞', v.isLiked ? '已赞' : '未赞'),
                        _Row('收藏', v.isFavorited ? '已收藏' : '未收藏'),
                        _Row(
                          '历史最远进度',
                          '${(v.watchProgress * 100).toStringAsFixed(1)}%',
                        ),
                        _Row(
                          '断点位置',
                          v.resumePosition > 0
                              ? _fmtDuration(
                                  Duration(milliseconds: v.resumePosition),
                                )
                              : '从头开始',
                        ),
                        _Row('累计观看', _fmtSpan(v.totalWatchMs)),
                        _Row('加入时间', _fmtDate(v.addedAt)),
                        _Row(
                          '上次播放',
                          v.lastPlayedAt > 0 ? _fmtDate(v.lastPlayedAt) : '从未',
                        ),
                      ]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    if (d.inMilliseconds <= 0) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String _fmtSpan(int ms) {
    if (ms <= 0) return '0 分钟';
    final total = Duration(milliseconds: ms);
    if (total.inMinutes < 1) return '${total.inSeconds} 秒';
    if (total.inHours < 1) return '${total.inMinutes} 分钟';
    final h = total.inHours;
    final m = total.inMinutes.remainder(60);
    return '$h 小时 $m 分钟';
  }

  static String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _Row {
  final String label;
  final String value;
  final bool copyable;
  final bool mono;
  final bool highlight;
  final String? hint;

  _Row(
    this.label,
    this.value, {
    this.copyable = false,
    this.mono = false,
    this.highlight = false,
    this.hint,
  });
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _Section(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in rows) _RowView(r),
        ],
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  final _Row row;
  const _RowView(this.row);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 82,
            child: Text(
              row.label,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: row.copyable
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: row.value));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('已复制')));
                      }
                    }
                  : null,
              child: MouseRegion(
                cursor: row.copyable
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: Text(
                  row.value,
                  style: TextStyle(
                    color: row.highlight
                        ? AppTheme.success
                        : AppTheme.textPrimary,
                    fontSize: 12,
                    height: 1.45,
                    fontFamily: row.mono ? 'Consolas' : null,
                    fontWeight: row.highlight
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          if (row.hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                row.hint!,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          if (row.copyable)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.copy_rounded,
                size: 12,
                color: AppTheme.textTertiary.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

/// 打开资源管理器定位文件
Future<void> revealFile(String path) async {
  if (!File(path).existsSync()) return;
  try {
    await Process.run('explorer.exe', <String>['/select,', path]);
  } catch (_) {}
}
