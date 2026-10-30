import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 沉浸模式下「控制层」的自动显隐
///
/// 全屏看视频时，进度条和按钮不该一直杵在那儿。主流播放器
/// （DPlayer / YouTube / PotPlayer / MPC-BE）都是同一套规则，这里照着做：
///
///   1. 鼠标一动 → 控制层立刻出现
///   2. 静止 4 秒 → 淡出
///   3. 视频暂停 → 一直显示（用户明显要操作）
///   4. 鼠标停在底部控制区 → 不淡出（正要点，别在这时候消失）
///   5. 淡出时鼠标指针也一起藏起来
///
/// 用法：把「画面」和「控制层」都放进 builder，
/// 画面永远在，控制层由 visible 决定淡入淡出。
class AutoHide extends StatefulWidget {
  /// visible = 控制层是否该显示
  final Widget Function(BuildContext context, bool visible) builder;

  /// false 时永远显示（非全屏时用）
  final bool enabled;

  /// true 时强制显示（暂停中、正在拖进度条）
  final bool forceShow;

  /// 静止多久后淡出
  final Duration hideAfter;

  /// 距底部多少像素以内算「鼠标在控制区」
  final double bottomZone;

  const AutoHide({
    super.key,
    required this.builder,
    this.enabled = true,
    this.forceShow = false,
    this.hideAfter = const Duration(seconds: 4),
    this.bottomZone = 150,
  });

  @override
  State<AutoHide> createState() => _AutoHideState();
}

class _AutoHideState extends State<AutoHide> {
  bool _visible = true;

  /// 鼠标是不是停在底部控制区。停在上面就别计时。
  bool _nearControls = false;

  Timer? _timer;

  /// 控制层到底该不该显示
  bool get _shouldShow => !widget.enabled || widget.forceShow || _visible;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant AutoHide old) {
    super.didUpdateWidget(old);

    if (old.enabled != widget.enabled) {
      if (widget.enabled) {
        _restart();
      } else {
        _showNow();
      }
      return;
    }

    // 暂停 → 立刻显示并停表；恢复播放 → 重新开始计时
    if (old.forceShow != widget.forceShow) {
      if (widget.forceShow) {
        _showNow();
      } else {
        _restart();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showNow() {
    _timer?.cancel();
    if (!_visible && mounted) setState(() => _visible = true);
  }

  void _restart() {
    _timer?.cancel();
    // 关掉自动隐藏 / 正在暂停 / 鼠标停在控制区 → 不设计时器
    if (!widget.enabled || widget.forceShow || _nearControls) return;

    _timer = Timer(widget.hideAfter, () {
      if (!mounted) return;
      if (!widget.enabled || widget.forceShow || _nearControls) return;
      setState(() => _visible = false);
    });
  }

  void _onHover(PointerHoverEvent e, double height) {
    // 鼠标靠近底部 → 认为用户要操作进度条，别让控制层消失
    _nearControls = e.localPosition.dy > height - widget.bottomZone;

    _showNow();
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final show = _shouldShow;
    final hideCursor = widget.enabled && !show;

    return LayoutBuilder(
      builder: (context, box) {
        return MouseRegion(
          // 控制层藏起来时，指针也一起藏，画面才干净
          cursor: hideCursor ? SystemMouseCursors.none : MouseCursor.defer,
          onHover: widget.enabled ? (e) => _onHover(e, box.maxHeight) : null,
          child: widget.builder(context, show),
        );
      },
    );
  }
}

/// 控制层的统一淡入淡出外壳
///
/// 单独抽出来是因为三处地方（标题、右侧按钮、底部播放条）都要用，
/// 而且必须同时带 IgnorePointer —— 否则淡出之后看不见却还能点到。
class FadeControls extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;

  const FadeControls({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: Curves.easeOut,
      child: IgnorePointer(ignoring: !visible, child: child),
    );
  }
}
