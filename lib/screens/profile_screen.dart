import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/paths.dart';
import '../core/theme.dart';
import '../providers/folder_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/video_provider.dart';
import '../widgets/app_context_menu.dart';

/// 我的：统计 + 全部设置 + 维护工具
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLibraryReset;

  const ProfileScreen({super.key, required this.onLibraryReset});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _thumbSize = 0;
  int _dbSize = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSizes());
  }

  void _refreshSizes() {
    if (!mounted) return;
    setState(() {
      _thumbSize = AppPaths.dirSize(AppPaths.thumbDir);
      final f = File(AppPaths.dbPath);
      _dbSize = f.existsSync() ? f.lengthSync() : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final videos = context.watch<VideoProvider>();
    final folders = context.watch<FolderProvider>();
    final player = context.watch<PlayerProvider>();

    final stats = videos.stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
      children: <Widget>[
        const Text(
          '我的',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // ── 统计 ──
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _StatCard('视频总数', '${stats['videos'] ?? 0}', Icons.video_library),
            _StatCard('文件夹', '${stats['folders'] ?? 0}', Icons.folder),
            _StatCard('播放次数', '${stats['plays'] ?? 0}', Icons.play_circle),
            _StatCard('点赞', '${stats['liked'] ?? 0}', Icons.favorite),
            _StatCard('收藏', '${stats['favorited'] ?? 0}', Icons.star),
            _StatCard('不感兴趣', '${stats['blocked'] ?? 0}', Icons.visibility_off),
          ],
        ),
        const SizedBox(height: 24),

        // ── 播放 ──
        _Section(
          title: '播放',
          children: <Widget>[
            _SegmentedRow<HwdecMode>(
              label: '解码方式',
              hint: '自动 = 能硬解就硬解，不行自动回落软解。改完会重开当前视频。',
              values: HwdecMode.values,
              current: settings.hwdecMode,
              labelOf: (m) => m.label,
              onChanged: (m) async {
                await settings.setHwdecMode(m);
                await player.setHwdecMode(m);
              },
            ),
            _SegmentedRow<CompletionBehavior>(
              label: '播完一条之后',
              hint: '手机版是死循环重播同一条，这里默认接着看下一条。',
              values: CompletionBehavior.values,
              current: settings.completionBehavior,
              labelOf: (c) => c.label,
              onChanged: (c) async {
                await settings.setCompletionBehavior(c);
                player.setCompletionBehavior(c);
              },
            ),
            _SliderRow(
              label: '默认倍速',
              value: settings.defaultSpeed,
              min: AppConstants.speedMin,
              max: AppConstants.speedMax,
              divisions: 15,
              text: '${settings.defaultSpeed.toStringAsFixed(2)}x',
              onChanged: (v) {
                settings.setDefaultSpeed(v);
                player.setSpeed(v);
              },
            ),
            _SwitchRow(
              label: '窗口失焦时自动暂停',
              hint: '切到别的程序就暂停，免得声音在后台响',
              value: settings.pauseOnBlur,
              onChanged: settings.setPauseOnBlur,
            ),
            _SwitchRow(
              label: '离开首页时自动暂停',
              hint: '去文件夹/发现页时停一下',
              value: settings.pauseOnPageChange,
              onChanged: settings.setPauseOnPageChange,
            ),
          ],
        ),

        // ── 弹幕 ──
        _Section(
          title: '弹幕',
          children: <Widget>[
            _SwitchRow(
              label: '显示弹幕',
              hint: '带时间戳的评论会在对应时间点飘过画面',
              value: settings.danmakuEnabled,
              onChanged: settings.setDanmakuEnabled,
            ),
            _SliderRow(
              label: '不透明度',
              value: settings.danmakuOpacity,
              min: 0.2,
              max: 1.0,
              divisions: 16,
              text: '${(settings.danmakuOpacity * 100).round()}%',
              onChanged: settings.setDanmakuOpacity,
            ),
            _SliderRow(
              label: '轨道数',
              value: settings.danmakuLanes.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              text: '${settings.danmakuLanes} 条',
              onChanged: (v) => settings.setDanmakuLanes(v.round()),
            ),
            _SliderRow(
              label: '字号',
              value: settings.danmakuFontSize,
              min: 10,
              max: 24,
              divisions: 14,
              text: '${settings.danmakuFontSize.round()} px',
              onChanged: settings.setDanmakuFontSize,
            ),
          ],
        ),

        // ── 扫描 ──
        _Section(
          title: '扫描',
          children: <Widget>[
            _SwitchRow(
              label: '跳过隐藏文件',
              hint: '文件名以 . 开头的忽略',
              value: settings.skipHidden,
              onChanged: settings.setSkipHidden,
            ),
            _SwitchRow(
              label: '深度扫描',
              hint: '白名单外的后缀也跑一遍 ffmpeg 探测（慢很多，但不会漏）',
              value: settings.deepScan,
              onChanged: settings.setDeepScan,
            ),
            _SwitchRow(
              label: '自动监视文件夹',
              hint: '往目录里丢新视频，5 秒后自动入库',
              value: settings.watchEnabled,
              onChanged: (v) async {
                await settings.setWatchEnabled(v);
                folders.setWatchEnabled(v);
              },
            ),
            _SliderRow(
              label: '最小文件大小',
              value: settings.minFileSizeKb.toDouble(),
              min: 0,
              max: 5000,
              divisions: 50,
              text: settings.minFileSizeKb == 0
                  ? '不限'
                  : '${settings.minFileSizeKb} KB',
              onChanged: (v) => settings.setMinFileSizeKb(v.round()),
            ),
          ],
        ),

        // ── 维护 ──
        _Section(
          title: '数据维护',
          children: <Widget>[
            _InfoRow('数据库', AppPaths.dbPath, mono: true),
            _InfoRow('数据库大小', AppPaths.formatBytes(_dbSize)),
            _InfoRow('缩略图缓存', AppPaths.formatBytes(_thumbSize)),
            _InfoRow(
              'ffmpeg',
              folders.ffmpegReady ? '已就绪' : '未找到（不影响播放）',
              ok: folders.ffmpegReady,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _ActionButton(
                  icon: Icons.refresh,
                  label: '重扫全部文件夹',
                  onTap: () async {
                    await folders.scanAll(
                      skipHidden: settings.skipHidden,
                      minFileSizeKb: settings.minFileSizeKb,
                      deepScan: settings.deepScan,
                    );
                    widget.onLibraryReset();
                    _refreshSizes();
                  },
                ),
                _ActionButton(
                  icon: Icons.image_outlined,
                  label: '补齐缺失缩略图',
                  onTap: () async {
                    await folders.generateMissingThumbnails();
                    _refreshSizes();
                  },
                ),
                _ActionButton(
                  icon: Icons.cleaning_services_outlined,
                  label: '清理缩略图缓存',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await confirmDialog(
                      context,
                      title: '清理缩略图缓存？',
                      message:
                          '会删掉 ${AppPaths.formatBytes(_thumbSize)} 的缩略图文件，'
                          '下次浏览时会重新生成。视频文件不受影响。',
                      confirmText: '清理',
                    );
                    if (!ok) return;
                    final freed = await folders.clearThumbCache();
                    _refreshSizes();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('已释放 ${AppPaths.formatBytes(freed)}'),
                      ),
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.restart_alt,
                  label: '重置「不感兴趣」(${stats['blocked'] ?? 0})',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await confirmDialog(
                      context,
                      title: '重置不感兴趣？',
                      message:
                          '被标成「不感兴趣」的 ${stats['blocked'] ?? 0} 个视频'
                          '会重新回到推荐池。',
                      confirmText: '重置',
                    );
                    if (!ok) return;
                    final n = await videos.resetNotInterested();
                    widget.onLibraryReset();
                    messenger.showSnackBar(
                      SnackBar(content: Text('已恢复 $n 个视频')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // ── 快捷键 ──
        _Section(title: '快捷键', children: <Widget>[const _ShortcutTable()]),

        // ── 关于 ──
        _Section(
          title: '关于',
          children: <Widget>[
            const _InfoRow('版本', '1.0.0  ·  Flutter Windows'),
            const _InfoRow('播放内核', 'libmpv（内置完整 FFmpeg，39 种容器直接解，不需要转码）'),
            const _InfoRow('数据位置', '全部存在本机，不上传、不联网'),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 15, color: AppTheme.textTertiary),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: AppTheme.panel(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                if (hint != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    hint!,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String text;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  final String label;
  final String hint;
  final List<T> values;
  final T current;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _SegmentedRow({
    required this.label,
    required this.hint,
    required this.values,
    required this.current,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final v in values)
                  GestureDetector(
                    onTap: () => onChanged(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: v == current
                            ? AppTheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        labelOf(v),
                        style: TextStyle(
                          color: v == current
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: v == current
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final bool? ok;

  const _InfoRow(this.label, this.value, {this.mono = false, this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: ok == null
                    ? AppTheme.textSecondary
                    : ok!
                    ? AppTheme.success
                    : AppTheme.favorite,
                fontSize: 12,
                height: 1.5,
                fontFamily: mono ? 'Consolas' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: 0.06)
                : AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutTable extends StatelessWidget {
  const _ShortcutTable();

  static const List<List<String>> _rows = <List<String>>[
    <String>['空格 / 单击画面', '播放 / 暂停'],
    <String>['↓ 或 J / 滚轮下滚', '下一条'],
    <String>['↑ 或 K / 滚轮上滚', '上一条'],
    <String>['← / →', '后退 / 前进 10 秒'],
    <String>['L', '点赞'],
    <String>['F', '收藏'],
    <String>['I', '不感兴趣'],
    <String>['C', '打开评论 / 弹幕'],
    <String>['D', '弹幕开关'],
    <String>['Tab', '视频信息面板'],
    <String>['M', '静音'],
    <String>['[ / ]', '减速 / 加速 0.1x'],
    <String>['1 ~ 6', '倍速 0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0'],
    <String>['F11', '进入 / 退出全屏'],
    <String>['Ctrl+O', '添加文件夹'],
    <String>['Ctrl+R', '重新洗牌推荐'],
    <String>['Esc', '全屏时先退全屏，否则关闭面板'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 28,
        runSpacing: 8,
        children: <Widget>[
          for (final r in _rows)
            SizedBox(
              width: 250,
              child: Row(
                children: <Widget>[
                  Container(
                    constraints: const BoxConstraints(minWidth: 110),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Text(
                      r[0],
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Consolas',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r[1],
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
