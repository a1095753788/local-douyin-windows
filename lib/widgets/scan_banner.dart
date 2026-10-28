import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../providers/folder_provider.dart';

/// 底部扫描 / 缩略图进度条
class ScanBanner extends StatelessWidget {
  final FolderProvider folders;
  final VoidCallback? onCancel;

  const ScanBanner({super.key, required this.folders, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final progress = folders.progress;
    final scanning = folders.scanning;
    final thumb = folders.thumbRunning;

    if (!scanning && !thumb) return const SizedBox.shrink();

    final String label;
    final double? value;
    final String? detail;

    if (scanning && progress != null) {
      label = '正在扫描「${progress.folderName}」';
      value = progress.total <= 0 ? null : progress.fraction;
      detail = progress.total <= 0
          ? '正在统计文件…'
          : '${progress.scanned} / ${progress.total}'
                '${progress.added > 0 ? '  ·  新增 ${progress.added}' : ''}';
    } else if (scanning) {
      label = '正在扫描…';
      value = null;
      detail = null;
    } else {
      label = '正在生成缩略图';
      value = folders.thumbTotal <= 0
          ? null
          : (folders.thumbDone / folders.thumbTotal).clamp(0.0, 1.0);
      detail = '${folders.thumbDone} / ${folders.thumbTotal}';
    }

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceHigh,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primary,
                ),
              ),
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(width: 12),
            Text(
              detail,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          if (scanning && onCancel != null) ...<Widget>[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('取消', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ],
      ),
    );
  }
}
