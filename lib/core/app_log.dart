import 'dart:io';

import 'package:path/path.dart' as p;

import 'paths.dart';

/// 极简运行日志
///
/// 桌面上出了问题没法看控制台，写一份到
/// `%APPDATA%\...\LocalDouyin\app.log`，出问题时让用户直接发这个文件。
/// 只记关键节点，不做滚动切割——正常用一年也到不了 1MB。
class AppLog {
  AppLog._();

  static String? _path;

  static void init() {
    try {
      _path = p.join(AppPaths.dataDir.path, 'app.log');
      final f = File(_path!);
      // 超过 2MB 就重来一份
      if (f.existsSync() && f.lengthSync() > 2 * 1024 * 1024) {
        f.deleteSync();
      }
      f.writeAsStringSync(
        '\n===== ${DateTime.now()} 启动 =====\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      _path = null;
    }
  }

  static void w(String tag, [Object? detail]) {
    final path = _path;
    if (path == null) return;
    try {
      final ts = DateTime.now().toIso8601String();
      File(path).writeAsStringSync(
        '$ts [$tag] ${detail ?? ''}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  static String get logPath => _path ?? '';
}
