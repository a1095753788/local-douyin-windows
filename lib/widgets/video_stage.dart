import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/theme.dart';
import '../data/models/video_item.dart';
import 'empty_state.dart';

/// 视频画面
///
/// 三层叠起来：
///   1. 缩略图（垫底，避免切视频时黑屏 200~400ms）
///   2. Video 画面（libmpv 出帧后把缩略图淡出）
///   3. 外部 overlay（弹幕 / 提示）
class VideoStage extends StatefulWidget {
  final VideoItem? video;
  final VideoController? controller;
  final bool playing;
  final bool buffering;
  final String? error;
  final bool showThumbnail;

  /// 画面之上要叠的东西（弹幕等）
  final Widget? overlay;

  /// 底部渐变遮罩之上要叠的东西（标题、进度条）
  final Widget? bottomOverlay;

  final VoidCallback? onTap;

  const VideoStage({
    super.key,
    required this.video,
    required this.controller,
    this.playing = false,
    this.buffering = false,
    this.error,
    this.showThumbnail = true,
    this.overlay,
    this.bottomOverlay,
    this.onTap,
  });

  @override
  State<VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<VideoStage> {
  bool _frameReady = false;

  @override
  void didUpdateWidget(covariant VideoStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video?.id != widget.video?.id) {
      _frameReady = false;
    }
    // 真正开始推进了就认为出帧了
    if (widget.playing && widget.video != null) {
      _frameReady = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;

    if (v == null) {
      return const ColoredBox(
        color: Colors.black,
        child: EmptyState(
          icon: Icons.video_library_outlined,
          title: '还没有可播放的视频',
          subtitle: '先去「文件夹」里添加一个目录，会自动扫描里面的视频',
        ),
      );
    }

    final thumb = widget.showThumbnail ? _buildThumb(v) : null;

    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1) 缩略图垫底
            if (thumb != null)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: _frameReady ? 0 : 1,
                child: thumb,
              ),

            // 2) 画面
            if (widget.controller != null)
              Video(
                controller: widget.controller!,
                fit: BoxFit.contain,
                controls: NoVideoControls,
                // 只在真正播放时防息屏
                wakelock: widget.playing,
              ),

            // 3) 上下渐变，让文字看得清
            const IgnorePointer(child: _Vignette()),

            // 4) 弹幕
            if (widget.overlay != null) widget.overlay!,

            // 5) 缓冲圈
            if (widget.buffering)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white70,
                  ),
                ),
              ),

            // 6) 错误
            if (widget.error != null && widget.error!.isNotEmpty)
              _ErrorBanner(message: widget.error!),

            // 7) 底部信息
            if (widget.bottomOverlay != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: widget.bottomOverlay!,
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildThumb(VideoItem v) {
    if (!v.hasThumbnail) {
      return ThumbPlaceholder(seed: v.id, iconSize: 56);
    }
    final f = File(v.thumbnailPath!);
    if (!f.existsSync()) {
      return ThumbPlaceholder(seed: v.id, iconSize: 56);
    }
    return Image.file(
      f,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => ThumbPlaceholder(seed: v.id, iconSize: 56),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.75),
          ],
          stops: const <double>[0.0, 0.18, 0.62, 1.0],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline, size: 16, color: AppTheme.danger),
                SizedBox(width: 8),
                Text(
                  '这条解不开',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '按 ↓ 跳过这一条',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
