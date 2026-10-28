import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/models/comment_item.dart';

class _Flying {
  final String id;
  final String text;
  final int lane;
  final int startMs;
  final bool mine;

  _Flying({
    required this.id,
    required this.text,
    required this.lane,
    required this.startMs,
    this.mine = false,
  });
}

/// 弹幕层
///
/// 手机版只做了「评论列表」，弹幕是摆设。桌面上把它做实：
/// 带 videoTimestamp 的评论在播放到对应时间点时从右侧飘到左侧。
///
/// 实现要点：
///   - 一个 Ticker 驱动整层，避免几十个 AnimationController
///   - 位置倒退超过 1 秒（用户拖了进度条）就清空重来
///   - 同一批弹幕按轨道轮转，轨道数可配
class DanmakuOverlay extends StatefulWidget {
  final List<CommentItem> pool;
  final Duration position;
  final bool enabled;
  final double opacity;
  final int lanes;
  final double fontSize;

  /// 刚发出的那条，立刻飘出来（不等时间轴）
  final CommentItem? justSent;

  const DanmakuOverlay({
    super.key,
    required this.pool,
    required this.position,
    this.enabled = true,
    this.opacity = 0.6,
    this.lanes = 5,
    this.fontSize = 13,
    this.justSent,
  });

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  static const int _travelMs = 9000;

  late final Ticker _ticker;
  int _nowMs = 0;
  int _lastTickMs = 0;

  final List<_Flying> _flying = <_Flying>[];
  final Set<String> _spawned = <String>{};
  int _laneCursor = 0;

  Duration _lastPos = Duration.zero;
  String? _lastJustSentId;

  @override
  void initState() {
    super.initState();
    _lastTickMs = DateTime.now().millisecondsSinceEpoch;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _nowMs += now - _lastTickMs;
    _lastTickMs = now;

    if (!widget.enabled) {
      if (_flying.isNotEmpty) setState(_flying.clear);
      return;
    }

    var changed = false;
    _flying.removeWhere((f) {
      final dead = _nowMs - f.startMs > _travelMs;
      if (dead) changed = true;
      return dead;
    });

    // 只在有东西在飞的时候重绘，静止时不 setState
    if (changed || _flying.isNotEmpty) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 拖进度条 → 重来
    if (widget.position + const Duration(seconds: 1) < _lastPos) {
      _flying.clear();
      _spawned.clear();
      _laneCursor = 0;
    }

    if (widget.enabled) {
      _spawnBetween(_lastPos, widget.position);
    }

    if (widget.justSent != null && widget.justSent!.id != _lastJustSentId) {
      _lastJustSentId = widget.justSent!.id;
      _spawnOne(widget.justSent!, mine: true);
    }

    _lastPos = widget.position;
  }

  void _spawnBetween(Duration from, Duration to) {
    final a = from.inMilliseconds;
    final b = to.inMilliseconds;
    if (b <= a) return;
    // 跨度过大说明是跳转，不补发历史弹幕
    if (b - a > 4000) return;

    for (final c in widget.pool) {
      final ts = c.videoTimestamp;
      if (ts == null) continue;
      if (ts > a && ts <= b && !_spawned.contains(c.id)) {
        _spawnOne(c);
      }
    }
  }

  void _spawnOne(CommentItem c, {bool mine = false}) {
    if (_spawned.contains(c.id)) return;
    _spawned.add(c.id);
    final lane = widget.lanes <= 0 ? 0 : _laneCursor % widget.lanes;
    _laneCursor++;
    _flying.add(
      _Flying(
        id: c.id,
        text: c.content,
        lane: lane,
        startMs: _nowMs,
        mine: mine,
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final laneHeight = widget.fontSize * 2.0;
          final maxLanes = widget.lanes <= 0 ? 1 : widget.lanes;
          final topPad = 56.0;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              for (final f in _flying)
                _buildItem(f, box.maxWidth, laneHeight, maxLanes, topPad),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem(
    _Flying f,
    double width,
    double laneHeight,
    int maxLanes,
    double topPad,
  ) {
    final elapsed = _nowMs - f.startMs;
    final t = (elapsed / _travelMs).clamp(0.0, 1.0);
    // 从右边界外进入，到左边界外离开
    const estimatedTextWidth = 260.0;
    final span = width + estimatedTextWidth;
    final x = width - t * span;

    return Positioned(
      left: x,
      top: topPad + (f.lane % maxLanes) * laneHeight,
      child: Opacity(
        opacity: widget.opacity.clamp(0.15, 1.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(4),
            border: f.mine
                ? Border.all(
                    color: const Color(0xFFFE2C55).withValues(alpha: 0.9),
                  )
                : null,
          ),
          child: Text(
            f.text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: f.mine ? const Color(0xFFFFD7DE) : Colors.white,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w500,
              height: 1.3,
              shadows: const <Shadow>[
                Shadow(color: Colors.black54, blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
