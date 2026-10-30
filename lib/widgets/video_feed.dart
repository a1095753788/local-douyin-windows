import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/models/video_item.dart';
import 'video_stage.dart';

/// 一条一屏的竖向切换
///
/// 手机上是手指上下滑，桌面上换成：
///   - 鼠标滚轮（累积到阈值才切一条，避免一滚飞十条）
///   - 鼠标按住上下拖
///   - 方向键 / 空格（由外层 AppShell 统一处理）
class VideoFeed extends StatefulWidget {
  final VideoItem? video;
  final int index;
  final VideoController? controller;
  final bool playing;
  final bool buffering;
  final String? error;
  final String? notice;

  final Widget? overlay;
  final Widget? bottomOverlay;

  /// 底部控制层是否可见（全屏沉浸模式）
  final bool controlsVisible;

  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback? onTap;

  const VideoFeed({
    super.key,
    required this.video,
    required this.index,
    required this.controller,
    required this.onNext,
    required this.onPrev,
    this.playing = false,
    this.buffering = false,
    this.error,
    this.notice,
    this.overlay,
    this.bottomOverlay,
    this.controlsVisible = true,
    this.onTap,
  });

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  int _dir = 1;

  double _wheelAcc = 0;
  DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant VideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _dir = widget.index > oldWidget.index ? 1 : -1;
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _fire(bool next) {
    final now = DateTime.now();
    // 一滚到底的连发保护
    if (now.difference(_lastFire).inMilliseconds < 180) return;
    _lastFire = now;
    _wheelAcc = 0;
    if (next) {
      widget.onNext();
    } else {
      widget.onPrev();
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    // 触摸板横向滚动忽略，纵向才切条
    if (event.scrollDelta.dy.abs() <= event.scrollDelta.dx.abs()) return;

    _wheelAcc += event.scrollDelta.dy;

    const threshold = 42.0;
    if (_wheelAcc >= threshold) {
      _fire(true);
    } else if (_wheelAcc <= -threshold) {
      _fire(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -240) {
            _fire(true);
          } else if (v > 240) {
            _fire(false);
          }
        },
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_anim.value);
            final dy = (1 - t) * 34.0 * _dir;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            );
          },
          child: VideoStage(
            video: widget.video,
            controller: widget.controller,
            playing: widget.playing,
            buffering: widget.buffering,
            error: widget.error,
            notice: widget.notice,
            overlay: widget.overlay,
            bottomOverlay: widget.bottomOverlay,
            controlsVisible: widget.controlsVisible,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}
