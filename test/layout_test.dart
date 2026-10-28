import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/core/theme.dart';
import 'package:local_douyin_win/data/models/video_item.dart';
import 'package:local_douyin_win/providers/comment_provider.dart';
import 'package:local_douyin_win/providers/player_provider.dart';
import 'package:local_douyin_win/providers/settings_provider.dart';
import 'package:local_douyin_win/providers/video_provider.dart';
import 'package:local_douyin_win/screens/home_screen.dart';
import 'package:local_douyin_win/widgets/app_context_menu.dart';
import 'package:provider/provider.dart';

/// 布局体检
///
/// 这个测试不验证业务，只验证「在目标尺寸下不会 RenderFlex overflow」。
/// 桌面版最容易犯的错就是宽度算死，窗口一缩就黄黑条纹。
void main() {
  final video = VideoItem(
    id: 'v1',
    path: r'C:\videos\a.mp4',
    name: 'a.mp4',
    folderId: 'f1',
    folderName: '测试文件夹',
    fileSize: 1024 * 1024 * 88,
    fileMtime: DateTime.now().millisecondsSinceEpoch,
    duration: 125000,
    width: 1920,
    height: 1080,
    addedAt: DateTime.now().millisecondsSinceEpoch,
    playCount: 12,
    isLiked: true,
    watchProgress: 0.42,
  );

  Widget buildHome({
    required Size size,
    bool showInfo = false,
    bool showComments = false,
    int tab = 0,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<PlayerProvider>(create: (_) => PlayerProvider()),
        ChangeNotifierProvider<VideoProvider>(create: (_) => VideoProvider()),
        ChangeNotifierProvider<CommentProvider>(
          create: (_) => CommentProvider(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: HomeScreen(
            tab: tab,
            onTab: (_) {},
            video: video,
            index: 0,
            length: 12,
            showInfo: showInfo,
            showComments: showComments,
            danmakuOn: true,
            onToggleInfo: () {},
            onToggleComments: () {},
            onToggleDanmaku: () {},
            onPlayPause: () {},
            onNext: () {},
            onPrev: () {},
            onAddFolder: () {},
            onRefresh: () {},
            onCloseInfo: () {},
            onCloseComments: () {},
            onFullscreen: () {},
            onAction: (VideoMenuAction a, VideoItem v) async {},
          ),
        ),
      ),
    );
  }

  Future<void> check(WidgetTester tester, Size size, Widget w) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '在 $size 下布局出错');
  }

  testWidgets('默认窗口 1280x800', (tester) async {
    await check(
      tester,
      const Size(1280, 800),
      buildHome(size: const Size(1280, 800)),
    );
  });

  testWidgets('最小窗口 900x600', (tester) async {
    await check(
      tester,
      const Size(900, 600),
      buildHome(size: const Size(900, 600)),
    );
  });

  testWidgets('1280x800 + 信息面板', (tester) async {
    await check(
      tester,
      const Size(1280, 800),
      buildHome(size: const Size(1280, 800), showInfo: true),
    );
  });

  testWidgets('1280x800 + 评论面板', (tester) async {
    await check(
      tester,
      const Size(1280, 800),
      buildHome(size: const Size(1280, 800), showComments: true),
    );
  });

  testWidgets('收藏页空状态', (tester) async {
    await check(
      tester,
      const Size(1280, 800),
      buildHome(size: const Size(1280, 800), tab: 1),
    );
  });
}
