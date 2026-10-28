import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/models/video_item.dart';

enum VideoMenuAction {
  playPause,
  like,
  favorite,
  notInterested,
  comment,
  info,
  revealInExplorer,
  openExternal,
  copyPath,
  deleteRecord,
  deleteToRecycleBin,
}

/// 视频右键菜单
Future<VideoMenuAction?> showVideoContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required VideoItem video,
  required bool playing,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return null;

  final result = await showMenu<VideoMenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    color: AppTheme.surfaceHigh,
    items: <PopupMenuEntry<VideoMenuAction>>[
      _item(
        VideoMenuAction.playPause,
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        playing ? '暂停' : '播放',
        hint: '空格',
      ),
      const PopupMenuDivider(height: 8),
      _item(
        VideoMenuAction.like,
        video.isLiked ? Icons.favorite : Icons.favorite_border,
        video.isLiked ? '取消点赞' : '点赞',
        hint: 'L',
      ),
      _item(
        VideoMenuAction.favorite,
        video.isFavorited ? Icons.star : Icons.star_border,
        video.isFavorited ? '取消收藏' : '收藏',
        hint: 'F',
      ),
      _item(
        VideoMenuAction.notInterested,
        Icons.visibility_off_outlined,
        '不感兴趣',
        hint: 'I',
      ),
      _item(
        VideoMenuAction.comment,
        Icons.mode_comment_outlined,
        '评论 / 弹幕',
        hint: 'C',
      ),
      _item(VideoMenuAction.info, Icons.info_outline, '视频信息', hint: 'Tab'),
      const PopupMenuDivider(height: 8),
      _item(VideoMenuAction.revealInExplorer, Icons.folder_open, '在资源管理器中显示'),
      _item(VideoMenuAction.openExternal, Icons.open_in_new, '用系统播放器打开'),
      _item(VideoMenuAction.copyPath, Icons.copy_rounded, '复制文件路径'),
      const PopupMenuDivider(height: 8),
      _item(
        VideoMenuAction.deleteRecord,
        Icons.remove_circle_outline,
        '从库里移除（不删文件）',
      ),
      _item(
        VideoMenuAction.deleteToRecycleBin,
        Icons.delete_outline,
        '移到回收站',
        danger: true,
      ),
    ],
  );

  if (result == VideoMenuAction.copyPath) {
    await Clipboard.setData(ClipboardData(text: video.path));
  }
  return result;
}

PopupMenuItem<VideoMenuAction> _item(
  VideoMenuAction value,
  IconData icon,
  String label, {
  String? hint,
  bool danger = false,
}) {
  final color = danger ? AppTheme.danger : AppTheme.textPrimary;
  return PopupMenuItem<VideoMenuAction>(
    value: value,
    height: 36,
    child: Row(
      children: <Widget>[
        Icon(
          icon,
          size: 15,
          color: danger ? AppTheme.danger : AppTheme.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(color: color, fontSize: 12.5)),
        ),
        if (hint != null)
          Text(
            hint,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
      ],
    ),
  );
}

/// 确认对话框
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
              : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return r ?? false;
}
