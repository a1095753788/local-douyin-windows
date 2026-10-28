import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'constants.dart';

/// 应用数据目录
///
/// 全部放在 `%APPDATA%\local_douyin_win\` 下。
/// 缩略图小（约 25KB/张），放这里没问题；
/// 但**转码文件不放这里**——转码功能已取消，这条约束也就没有了。
class AppPaths {
  AppPaths._();

  static late final Directory dataDir;
  static late final String dbPath;
  static late final Directory thumbDir;

  static Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    dataDir = Directory(p.join(support.path, AppConstants.appNameEn));
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    dbPath = p.join(dataDir.path, AppConstants.dbName);

    thumbDir = Directory(p.join(dataDir.path, 'thumbnails'));
    if (!thumbDir.existsSync()) {
      thumbDir.createSync(recursive: true);
    }
  }

  /// 允许用户把缩略图目录改到别的盘
  static Directory customThumbDir(String? override) {
    if (override == null || override.trim().isEmpty) return thumbDir;
    final d = Directory(override);
    if (!d.existsSync()) {
      try {
        d.createSync(recursive: true);
      } catch (_) {
        return thumbDir;
      }
    }
    return d;
  }

  static String thumbPathFor(String videoId, [Directory? dir]) =>
      p.join((dir ?? thumbDir).path, '$videoId.jpg');

  /// 目录占用大小（字节）
  static int dirSize(Directory dir) {
    if (!dir.existsSync()) return 0;
    var total = 0;
    try {
      for (final e in dir.listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += e.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
