import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/video_item.dart';
import '../providers/comment_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/video_provider.dart';
import '../widgets/app_context_menu.dart';
import '../widgets/auto_hide.dart';
import '../widgets/comment_panel.dart';
import '../widgets/danmaku_overlay.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_panel.dart';
import '../widgets/player_bar.dart';
import '../widgets/side_actions.dart';
import '../widgets/video_feed.dart';

/// 首页：推荐流 / 收藏流
///
/// 纯展示 + 转发回调，所有「当前在播哪一条」的决策在 AppShell。
class HomeScreen extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;

  final VideoItem? video;
  final int index;
  final int length;

  final bool showInfo;
  final bool showComments;
  final bool danmakuOn;

  /// 全屏沉浸模式：隐藏侧边栏、顶部 tab，控制层跟着鼠标自动显隐
  final bool immersive;

  final VoidCallback onToggleInfo;
  final VoidCallback onToggleComments;
  final VoidCallback onToggleDanmaku;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onAddFolder;
  final VoidCallback onRefresh;
  final VoidCallback onCloseInfo;
  final VoidCallback onCloseComments;
  final VoidCallback onFullscreen;

  /// 右键菜单 / 侧栏动作统一回传
  final Future<void> Function(VideoMenuAction action, VideoItem v) onAction;

  const HomeScreen({
    super.key,
    required this.tab,
    required this.onTab,
    required this.video,
    required this.index,
    required this.length,
    required this.showInfo,
    required this.showComments,
    required this.danmakuOn,
    this.immersive = false,
    required this.onToggleInfo,
    required this.onToggleComments,
    required this.onToggleDanmaku,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onAddFolder,
    required this.onRefresh,
    required this.onCloseInfo,
    required this.onCloseComments,
    required this.onFullscreen,
    required this.onAction,
  });

  /// 收藏页空状态
  ///
  /// 必须是 Positioned。如果写成普通子元素（比如条件不满足时返回
  /// SizedBox.shrink），Stack 就会按「非定位子元素」的尺寸算大小，
  /// 而那个尺寸是 0×0 —— 整个画面区域会被压没，视频直接不显示。
  static const Widget _emptyFavorites = Positioned.fill(
    child: IgnorePointer(
      child: EmptyState(
        icon: Icons.star_border_rounded,
        title: '收藏夹是空的',
        subtitle: '在推荐流里点右侧的星标，视频就会收进这里。\n收藏过的视频不会再出现在推荐流里。',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final videos = context.watch<VideoProvider>();
    final comments = context.watch<CommentProvider>();
    final settings = context.watch<SettingsProvider>();

    final v = video;
    final favTab = tab == 1;

    // 画面层：永远在，不参与淡入淡出。
    // 做成函数是因为全屏时它的 controlsVisible 要由 AutoHide 决定。
    Widget buildVideoLayer(bool controlsVisible) => Positioned.fill(
      child: GestureDetector(
        onSecondaryTapDown: v == null
            ? null
            : (d) async {
                final action = await showVideoContextMenu(
                  context: context,
                  globalPosition: d.globalPosition,
                  video: v,
                  playing: player.playing,
                );
                if (action != null) {
                  await onAction(action, v);
                }
              },
        child: VideoFeed(
          video: v,
          index: index,
          controller: player.controller,
          playing: player.playing,
          buffering: player.buffering,
          error: player.error,
          notice: player.notice,
          onNext: onNext,
          onPrev: onPrev,
          onTap: onPlayPause,
          overlay: v == null
              ? null
              : DanmakuOverlay(
                  key: ValueKey<String>('dm-${v.id}'),
                  pool: comments.danmakuPool,
                  position: player.position,
                  enabled: danmakuOn && settings.danmakuEnabled,
                  opacity: settings.danmakuOpacity,
                  lanes: settings.danmakuLanes,
                  fontSize: settings.danmakuFontSize,
                ),
          bottomOverlay: v == null
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TitleBlock(
                      video: v,
                      positionText: '${index + 1} / $length',
                    ),
                    PlayerBar(
                      playing: player.playing,
                      position: player.position,
                      duration: player.duration,
                      speed: player.speed,
                      volume: player.volume,
                      muted: player.muted,
                      onPlayPause: onPlayPause,
                      onSeek: player.seek,
                      onSpeed: (s) {
                        player.setSpeed(s);
                        settings.setDefaultSpeed(s);
                      },
                      onVolume: player.setVolume,
                      onToggleMute: player.toggleMute,
                      onPrev: onPrev,
                      onNext: onNext,
                      onFullscreen: onFullscreen,
                      fullscreen: immersive,
                    ),
                  ],
                ),
          controlsVisible: controlsVisible,
        ),
      ),
    );

    // 顶部 tab。全屏时不要——切页靠侧边栏，而侧边栏在全屏时已经藏了。
    final Widget topBar = Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: _TopBar(
        tab: tab,
        onTab: onTab,
        onRefresh: onRefresh,
        onAddFolder: onAddFolder,
        favCount: videos.favorites.length,
        recommendCount: videos.feedLength,
      ),
    );

    // 右侧操作条（只做内容，Positioned 由外面加，方便套淡入淡出）
    final Widget sideBarContent = v == null
        ? const SizedBox.shrink()
        : SideActions(
            video: v,
            commentCount: videos.commentCountOf(v.id),
            danmakuEnabled: danmakuOn,
            infoVisible: showInfo,
            onLike: () => onAction(VideoMenuAction.like, v),
            onFavorite: () => onAction(VideoMenuAction.favorite, v),
            onNotInterested: () => onAction(VideoMenuAction.notInterested, v),
            onComment: onToggleComments,
            onToggleDanmaku: onToggleDanmaku,
            onToggleInfo: onToggleInfo,
            onMore: () => _showMoreMenu(context, v),
          );

    final Widget feedArea;

    if (immersive) {
      // 全屏：只剩画面 + 会自己藏起来的控制层
      feedArea = AutoHide(
        enabled: true,
        // 暂停时强制显示——用户按了暂停，多半正要操作
        forceShow: !player.playing,
        builder: (context, visible) {
          return Stack(
            children: <Widget>[
              buildVideoLayer(visible),
              if (v != null)
                Positioned(
                  right: 12,
                  bottom: 168,
                  child: FadeControls(visible: visible, child: sideBarContent),
                ),
              if (favTab && length == 0) _emptyFavorites,
            ],
          );
        },
      );
    } else {
      feedArea = Stack(
        children: <Widget>[
          buildVideoLayer(true),
          topBar,
          if (v != null)
            Positioned(right: 12, bottom: 168, child: sideBarContent),
          if (favTab && length == 0) _emptyFavorites,
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: feedArea),
        if (showInfo)
          InfoPanel(
            video: v,
            container: player.container,
            codec: player.codec,
            hwdecActual: player.hwdecActual,
            position: player.position,
            duration: player.duration,
            speed: player.speed,
            onClose: onCloseInfo,
          ),
        if (showComments)
          CommentPanel(
            comments: comments.comments,
            position: player.position,
            loading: comments.loading,
            onClose: onCloseComments,
            onSubmit: (text, asDanmaku) async {
              if (v == null) return;
              await comments.add(
                v.id,
                text,
                timestampMs: asDanmaku ? player.position.inMilliseconds : null,
              );
            },
            onLike: (c) => comments.toggleLike(c.id),
            onDelete: (c) => comments.delete(c.id),
            onSeekTo: (c) {
              final ts = c.videoTimestamp;
              if (ts != null) player.seek(Duration(milliseconds: ts));
            },
          ),
      ],
    );
  }

  Future<void> _showMoreMenu(BuildContext context, VideoItem v) async {
    final box = context.findRenderObject() as RenderBox?;
    final pos = box == null
        ? const Offset(400, 300)
        : box.localToGlobal(Offset(box.size.width - 40, box.size.height - 300));
    final player = context.read<PlayerProvider>();
    final action = await showVideoContextMenu(
      context: context,
      globalPosition: pos,
      video: v,
      playing: player.playing,
    );
    if (action != null) await onAction(action, v);
  }
}

class _TopBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onRefresh;
  final VoidCallback onAddFolder;
  final int favCount;
  final int recommendCount;

  const _TopBar({
    required this.tab,
    required this.onTab,
    required this.onRefresh,
    required this.onAddFolder,
    required this.favCount,
    required this.recommendCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: Row(
        children: <Widget>[
          _TabChip(
            label: '推荐',
            count: recommendCount,
            active: tab == 0,
            onTap: () => onTab(0),
          ),
          const SizedBox(width: 6),
          _TabChip(
            label: '收藏',
            count: favCount,
            active: tab == 1,
            onTap: () => onTab(1),
          ),
          const Spacer(),
          _GhostButton(
            icon: Icons.refresh,
            tip: '重新洗牌推荐  (Ctrl+R)',
            onTap: onRefresh,
          ),
          const SizedBox(width: 6),
          _GhostButton(
            icon: Icons.create_new_folder_outlined,
            tip: '添加文件夹  (Ctrl+O)',
            onTap: onAddFolder,
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count > 0) ...<Widget>[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: active ? Colors.white54 : Colors.white30,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  const _GhostButton({
    required this.icon,
    required this.tip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final VideoItem video;
  final String positionText;

  const _TitleBlock({required this.video, required this.positionText});

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (video.durationText.isNotEmpty) video.durationText,
      if (video.resolution.isNotEmpty) video.resolution,
      video.fileSizeFormatted,
      if (video.playCount > 0) '看过 ${video.playCount} 次',
      positionText,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (video.folderName.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    video.folderName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              if (video.isFavorited)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.star, size: 13, color: AppTheme.favorite),
                ),
              Expanded(
                child: Text(
                  video.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: <Shadow>[
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            meta.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11.5,
              shadows: <Shadow>[Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
