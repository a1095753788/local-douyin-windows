import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/video_item.dart';

/// 右侧竖排操作条（点赞 / 收藏 / 不感兴趣 / 评论 / 弹幕 / 信息 / 更多）
class SideActions extends StatelessWidget {
  final VideoItem? video;
  final int commentCount;
  final bool danmakuEnabled;
  final bool infoVisible;

  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onNotInterested;
  final VoidCallback onComment;
  final VoidCallback onToggleDanmaku;
  final VoidCallback onToggleInfo;
  final VoidCallback onMore;

  const SideActions({
    super.key,
    required this.video,
    this.commentCount = 0,
    this.danmakuEnabled = true,
    this.infoVisible = false,
    required this.onLike,
    required this.onFavorite,
    required this.onNotInterested,
    required this.onComment,
    required this.onToggleDanmaku,
    required this.onToggleInfo,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final v = video;
    final liked = v?.isLiked ?? false;
    final fav = v?.isFavorited ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ActionButton(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? AppTheme.like : Colors.white,
          label: _count(v?.likeCount ?? 0),
          tooltip: '点赞  (L)',
          onTap: v == null ? null : onLike,
          highlight: liked,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: fav ? Icons.star : Icons.star_border,
          color: fav ? AppTheme.favorite : Colors.white,
          label: fav ? '已收藏' : '收藏',
          tooltip: '收藏  (F) — 收藏后不再出现在推荐里',
          onTap: v == null ? null : onFavorite,
          highlight: fav,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.visibility_off_outlined,
          label: '不感兴趣',
          tooltip: '不感兴趣  (I)',
          onTap: v == null ? null : onNotInterested,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: _count(commentCount),
          tooltip: '评论 / 弹幕  (C)',
          onTap: v == null ? null : onComment,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: danmakuEnabled ? Icons.subtitles : Icons.subtitles_off_outlined,
          label: danmakuEnabled ? '弹幕开' : '弹幕关',
          tooltip: '弹幕开关  (D)',
          onTap: onToggleDanmaku,
          highlight: danmakuEnabled,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.info_outline,
          label: '信息',
          tooltip: '视频信息  (Tab)',
          onTap: onToggleInfo,
          highlight: infoVisible,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.more_horiz,
          label: '更多',
          tooltip: '更多操作  (右键也能开菜单)',
          onTap: onMore,
        ),
      ],
    );
  }

  static String _count(int n) {
    if (n <= 0) return '0';
    if (n < 10000) return '$n';
    return '${(n / 10000).toStringAsFixed(1)}w';
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool highlight;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onTap,
    this.color = Colors.white,
    this.highlight = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hover
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.32),
                    border: Border.all(
                      color: widget.highlight
                          ? widget.color.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 23,
                    color: enabled
                        ? widget.color
                        : widget.color.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                    height: 1.2,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
