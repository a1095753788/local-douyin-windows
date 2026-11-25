import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 网络源地址输入框。
///
/// 必须做成有状态组件：TextEditingController 要跟着对话框的 State 一起销毁。
/// 如果在 showDialog 返回之后再 dispose，会赶上对话框的退场动画——那时输入框
/// 仍在重建并访问控制器，轻则报 used after disposed，重则触发框架的
/// `_dependents.isEmpty` 断言把界面刷成红屏。
class NetworkSourceDialog extends StatefulWidget {
  const NetworkSourceDialog({super.key});

  @override
  State<NetworkSourceDialog> createState() => _NetworkSourceDialogState();
}

class _NetworkSourceDialogState extends State<NetworkSourceDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加网络视频源', style: TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '输入服务器地址，App 会读取 /api/videos.json，把视频清单加入库，'
            '之后像本地视频一样直接播放。',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'http://192.168.31.41:8765',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('添加'),
        ),
      ],
    );
  }
}
