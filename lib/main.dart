import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/app_log.dart';
import 'core/constants.dart';
import 'core/paths.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'platform/ffmpeg.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv 的初始化必须在任何 Player 创建之前
  MediaKit.ensureInitialized();

  // 数据目录 + SQLite
  await AppPaths.init();
  AppLog.init();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await AppDatabase.instance.init();

  // 设置
  final settings = SettingsProvider();
  await settings.load();

  // ffmpeg：内置 → PATH → 用户指定。找不到也能播，只是没有缩略图和时长
  final ffmpeg = await FfmpegService.locate(userOverride: settings.ffmpegPath);
  AppLog.w('ffmpeg', ffmpeg ?? '未找到');

  // 窗口
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(
      AppConstants.windowDefaultWidth,
      AppConstants.windowDefaultHeight,
    ),
    minimumSize: Size(
      AppConstants.windowMinWidth,
      AppConstants.windowMinHeight,
    ),
    center: true,
    backgroundColor: AppTheme.bg,
    title: AppConstants.appName,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 拦截关闭，先把播放进度写回库再退出
  await windowManager.setPreventClose(true);

  // 窗口最小尺寸之外再兜一层：防止配置文件被改坏后开出一个 1x1 的窗
  try {
    final size = await windowManager.getSize();
    if (size.width < AppConstants.windowMinWidth ||
        size.height < AppConstants.windowMinHeight) {
      await windowManager.setSize(
        const Size(
          AppConstants.windowDefaultWidth,
          AppConstants.windowDefaultHeight,
        ),
      );
      await windowManager.center();
    }
  } catch (_) {}

  runApp(LocalDouyinApp(settings: settings));
}
