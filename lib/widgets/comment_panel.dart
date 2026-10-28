import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/models/comment_item.dart';

/// 评论 / 弹幕面板
class CommentPanel extends StatefulWidget {
  final List<CommentItem> comments;
  final Duration position;
  final bool loading;

  final void Function(String text, bool asDanmaku) onSubmit;
  final void Function(CommentItem c) onLike;
  final void Function(CommentItem c) onDelete;
  final void Function(CommentItem c) onSeekTo;
  final VoidCallback onClose;

  const CommentPanel({
    super.key,
    required this.comments,
    required this.position,
    required this.onSubmit,
    required this.onLike,
    required this.onDelete,
    required this.onSeekTo,
    required this.onClose,
    this.loading = false,
  });

  @override
  State<CommentPanel> createState() => _CommentPanelState();
}

class _CommentPanelState extends State<CommentPanel> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _asDanmaku = true;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text, _asDanmaku);
    _ctrl.clear();
    _focus.requestFocus();
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          // 头
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: <Widget>[
                Text(
                  '评论 ${widget.comments.length}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  iconSize: 18,
                  tooltip: '关闭  (Esc)',
                  icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // 列表
          Expanded(
            child: widget.loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : widget.comments.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '还没有评论\n说两句吧，勾上「弹幕」就会飘在画面上',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                          height: 1.8,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.comments.length,
                    itemBuilder: (context, i) => _CommentTile(
                      comment: widget.comments[i],
                      onLike: () => widget.onLike(widget.comments[i]),
                      onDelete: () => widget.onDelete(widget.comments[i]),
                      onSeekTo: () => widget.onSeekTo(widget.comments[i]),
                    ),
                  ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // 输入
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Checkbox(
                      value: _asDanmaku,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(
                        color: AppTheme.textTertiary,
                        width: 1.2,
                      ),
                      onChanged: (v) => setState(() => _asDanmaku = v ?? false),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '作为弹幕 · 记在 ${_fmt(widget.position)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Focus(
                        // Ctrl+Enter 发送（多行输入框里 Enter 只换行）
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              HardwareKeyboard.instance.isControlPressed) {
                            _submit();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          maxLines: 3,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: '说点什么…  (Ctrl+Enter 发送)',
                            hintStyle: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12.5,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceHigh,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('发送'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final CommentItem comment;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onSeekTo;

  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onDelete,
    required this.onSeekTo,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _hover = false;

  static String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        color: _hover ? Colors.white.withValues(alpha: 0.03) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 13,
              backgroundColor: AppTheme.surfaceHigh,
              child: Text(
                c.userName.isEmpty ? '?' : c.userName.substring(0, 1),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        c.userName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.timeAgo,
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      if (c.videoTimestamp != null) ...<Widget>[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onSeekTo,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              _fmt(c.videoTimestamp!),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.content,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InkWell(
                  onTap: widget.onLike,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      c.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: c.isLiked ? AppTheme.like : AppTheme.textTertiary,
                    ),
                  ),
                ),
                if (c.likeCount > 0)
                  Text(
                    '${c.likeCount}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            if (_hover)
              InkWell(
                onTap: widget.onDelete,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
