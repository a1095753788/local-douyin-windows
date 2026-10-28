import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 统一的空状态 / 引导页
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// 加载中
class LoadingState extends StatelessWidget {
  final String text;
  const LoadingState({super.key, this.text = '加载中…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// 缩略图缺失时的占位（按文件名散列出一个稳定色）
class ThumbPlaceholder extends StatelessWidget {
  final String seed;
  final IconData icon;
  final double iconSize;

  const ThumbPlaceholder({
    super.key,
    required this.seed,
    this.icon = Icons.movie_outlined,
    this.iconSize = 28,
  });

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF2B1B33), Color(0xFF4A2545)],
    <Color>[Color(0xFF1B2733), Color(0xFF25404A)],
    <Color>[Color(0xFF33231B), Color(0xFF4A3525)],
    <Color>[Color(0xFF1B3326), Color(0xFF254A38)],
    <Color>[Color(0xFF2A2A33), Color(0xFF3D3D4A)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = seed.hashCode.abs() % _palettes.length;
    final colors = _palettes[idx];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}
