import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/video_item.dart';
import 'empty_state.dart';

/// 网格卡片（收藏页 / 发现页 / 文件夹详情共用）
class VideoCard extends StatefulWidget {
  final VideoItem video;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onRemoveFavorite;
  final VoidCallback? onDelete;
  final bool showRemoveFavorite;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.onPlay,
    this.onRemoveFavorite,
    this.onDelete,
    this.showRemoveFavorite = false,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.video;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hover
                  ? AppTheme.primary.withValues(alpha: 0.55)
                  : AppTheme.border,
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 封面
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _thumb(v),
                    // 播放按钮
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: _hover ? 1 : 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.32),
                        child: Center(
                          child: GestureDetector(
                            onTap: widget.onPlay,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 时长
                    if (v.durationText.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            v.durationText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                    // 进度条
                    if (v.watchProgress > 0.01)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: v.watchProgress.clamp(0.0, 1.0),
                          minHeight: 2.5,
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary,
                          ),
                        ),
                      ),
                    // 角标
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Row(
                        children: <Widget>[
                          if (v.isFavorited)
                            _badge(Icons.star, AppTheme.favorite),
                          if (v.isLiked) _badge(Icons.favorite, AppTheme.like),
                        ],
                      ),
                    ),
                    // 悬浮操作
                    if (_hover &&
                        (widget.showRemoveFavorite || widget.onDelete != null))
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Row(
                          children: <Widget>[
                            if (widget.showRemoveFavorite)
                              _miniBtn(
                                Icons.star,
                                AppTheme.favorite,
                                widget.onRemoveFavorite,
                                '取消收藏',
                              ),
                            if (widget.onDelete != null)
                              _miniBtn(
                                Icons.delete_outline,
                                Colors.white,
                                widget.onDelete,
                                '删除',
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // 文字
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      v.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            v.folderName.isEmpty ? '未知文件夹' : v.folderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          v.fileSizeFormatted,
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (v.playCount > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '看过 ${v.playCount} 次'
                        '${v.resolution.isEmpty ? '' : ' · ${v.resolution}'}',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(VideoItem v) {
    if (!v.hasThumbnail) {
      return ThumbPlaceholder(seed: v.id, iconSize: 22);
    }
    final f = File(v.thumbnailPath!);
    if (!f.existsSync()) {
      return ThumbPlaceholder(seed: v.id, iconSize: 22);
    }
    return Image.file(
      f,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ThumbPlaceholder(seed: v.id, iconSize: 22),
    );
  }

  Widget _badge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 11, color: color),
    );
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback? onTap, String tip) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    );
  }
}
