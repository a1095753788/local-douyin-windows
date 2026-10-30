import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// 底部播放控制条
class PlayerBar extends StatefulWidget {
  final bool playing;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;
  final bool muted;

  /// 当前是否全屏（决定全屏按钮显示「进入」还是「退出」）
  final bool fullscreen;

  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onToggleMute;
  final VoidCallback? onFullscreen;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const PlayerBar({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    required this.speed,
    required this.volume,
    required this.muted,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSpeed,
    required this.onVolume,
    required this.onToggleMute,
    required this.onPrev,
    required this.onNext,
    this.fullscreen = false,
    this.onFullscreen,
  });

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  double? _dragValue;

  static String _fmt(Duration d) {
    if (d.inMilliseconds <= 0) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds;
    final pos = widget.position.inMilliseconds;
    final value =
        _dragValue ?? (total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 进度
          Row(
            children: <Widget>[
              Text(
                _fmt(
                  _dragValue == null
                      ? widget.position
                      : Duration(milliseconds: (total * _dragValue!).round()),
                ),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    inactiveTrackColor: Colors.white24,
                  ),
                  child: Slider(
                    value: value,
                    onChanged: total <= 0
                        ? null
                        : (v) => setState(() => _dragValue = v),
                    onChangeEnd: total <= 0
                        ? null
                        : (v) {
                            widget.onSeek(
                              Duration(milliseconds: (total * v).round()),
                            );
                            setState(() => _dragValue = null);
                          },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _fmt(widget.duration),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          // 按钮行
          Row(
            children: <Widget>[
              _Btn(
                icon: Icons.skip_previous,
                tooltip: '上一条  (↑ / K)',
                onTap: widget.onPrev,
              ),
              const SizedBox(width: 6),
              _Btn(
                icon: widget.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                tooltip: '播放 / 暂停  (空格)',
                size: 30,
                filled: true,
                onTap: widget.onPlayPause,
              ),
              const SizedBox(width: 6),
              _Btn(
                icon: Icons.skip_next,
                tooltip: '下一条  (↓ / J)',
                onTap: widget.onNext,
              ),

              const SizedBox(width: 18),
              _Btn(
                icon: Icons.replay_10,
                tooltip: '后退 10 秒  (←)',
                size: 19,
                onTap: () => widget.onSeek(
                  widget.position - const Duration(seconds: 10),
                ),
              ),
              const SizedBox(width: 4),
              _Btn(
                icon: Icons.forward_10,
                tooltip: '前进 10 秒  (→)',
                size: 19,
                onTap: () => widget.onSeek(
                  widget.position + const Duration(seconds: 10),
                ),
              ),

              const Spacer(),

              // 倍速
              _SpeedButton(speed: widget.speed, onChanged: widget.onSpeed),

              const SizedBox(width: 12),

              // 音量
              _Btn(
                icon: widget.muted
                    ? Icons.volume_off_rounded
                    : widget.volume <= 0
                    ? Icons.volume_mute_rounded
                    : widget.volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
                tooltip: '静音  (M)',
                size: 19,
                onTap: widget.onToggleMute,
              ),
              SizedBox(
                width: 76,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    inactiveTrackColor: Colors.white24,
                  ),
                  child: Slider(
                    value: widget.muted ? 0 : widget.volume.clamp(0.0, 1.0),
                    onChanged: widget.onVolume,
                  ),
                ),
              ),

              const SizedBox(width: 8),
              if (widget.onFullscreen != null)
                _Btn(
                  icon: widget.fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: widget.fullscreen
                      ? '退出全屏  (F11 / Esc)'
                      : '全屏  (F11)',
                  size: 20,
                  onTap: widget.onFullscreen!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final bool filled;

  const _Btn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 22,
    this.filled = false,
  });

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.filled ? 38 : 30,
            height: widget.filled ? 38 : 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.filled
                  ? AppTheme.primary
                  : _hover
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: widget.filled ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;

  const _SpeedButton({required this.speed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: '倍速  ( [ / ] )',
      onSelected: onChanged,
      itemBuilder: (context) => <PopupMenuEntry<double>>[
        for (final s in AppConstants.speedPresets)
          PopupMenuItem<double>(
            value: s,
            height: 34,
            child: Row(
              children: <Widget>[
                SizedBox(width: 44, child: Text('${s}x')),
                if ((speed - s).abs() < 0.001)
                  const Icon(Icons.check, size: 14, color: AppTheme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 1 : 2)}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
