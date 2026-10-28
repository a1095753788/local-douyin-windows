import 'dart:async';
import 'dart:io';

import 'package:watcher/watcher.dart';

import '../core/constants.dart';
import '../data/models/folder_item.dart';

/// 文件夹监视
///
/// 手机版只能手动点「重扫」。桌面版有文件系统能力，
/// 用户把新视频拖进目录，这里 5 秒防抖后自动触发增量扫描。
///
/// 只监视根目录（非递归）——递归会耗光文件句柄。
class WatchService {
  final Map<String, StreamSubscription<WatchEvent>> _subs =
      <String, StreamSubscription<WatchEvent>>{};
  final Map<String, Timer> _debounce = <String, Timer>{};

  void Function(String folderId)? onChanged;

  bool isWatching(String folderId) => _subs.containsKey(folderId);

  int get watchCount => _subs.length;

  /// 开始监视一个文件夹
  void watch(FolderItem folder) {
    if (_subs.containsKey(folder.id)) return;
    if (!Directory(folder.path).existsSync()) return;

    try {
      final watcher = DirectoryWatcher(
        folder.path,
        pollingDelay: const Duration(seconds: 3),
      );

      _subs[folder.id] = watcher.events.listen(
        (event) {
          // 忽略临时文件与隐藏文件
          final name = event.path.split(RegExp(r'[/\\]')).last;
          if (name.startsWith('.')) return;
          if (name.endsWith('.tmp') || name.endsWith('.part')) return;
          _schedule(folder.id);
        },
        onError: (_) {
          // 网络盘断开等情况：静默降级为手动扫描
          unwatch(folder.id);
        },
        cancelOnError: true,
      );
    } catch (_) {
      // 监视失败不影响主流程
    }
  }

  void _schedule(String folderId) {
    _debounce[folderId]?.cancel();
    _debounce[folderId] = Timer(
      const Duration(milliseconds: AppConstants.watchDebounceMs),
      () => onChanged?.call(folderId),
    );
  }

  void unwatch(String folderId) {
    _subs.remove(folderId)?.cancel();
    _debounce.remove(folderId)?.cancel();
  }

  void unwatchAll() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
  }

  /// 根据文件夹列表重建监视（autoScan 开着的才监视）
  void sync(List<FolderItem> folders, {required bool enabled}) {
    if (!enabled) {
      unwatchAll();
      return;
    }
    final wanted = <String>{
      for (final f in folders)
        if (f.autoScan && f.available) f.id,
    };

    // 移除不需要的
    for (final id in _subs.keys.toList()) {
      if (!wanted.contains(id)) unwatch(id);
    }
    // 添加新的
    for (final f in folders) {
      if (wanted.contains(f.id) && !_subs.containsKey(f.id)) {
        watch(f);
      }
    }
  }

  void dispose() => unwatchAll();
}
