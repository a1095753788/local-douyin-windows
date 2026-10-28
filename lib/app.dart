import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/comment_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/player_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/video_provider.dart';
import 'screens/shell.dart';

class LocalDouyinApp extends StatelessWidget {
  final SettingsProvider settings;

  const LocalDouyinApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<PlayerProvider>(create: (_) => PlayerProvider()),
        ChangeNotifierProvider<FolderProvider>(create: (_) => FolderProvider()),
        ChangeNotifierProvider<VideoProvider>(create: (_) => VideoProvider()),
        ChangeNotifierProvider<CommentProvider>(
          create: (_) => CommentProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        scrollBehavior: const _DesktopScrollBehavior(),
        home: const AppShell(),
      ),
    );
  }
}

/// 桌面上允许鼠标拖拽滚动（默认只认触摸）
class _DesktopScrollBehavior extends MaterialScrollBehavior {
  const _DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
