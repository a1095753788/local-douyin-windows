import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/data/models/video_item.dart';
import 'package:local_douyin_win/widgets/video_stage.dart';

/// 错误遮罩的显示条件
///
/// 背景：media_kit 的 `stream.error` 不是「视频打不开」，
/// 而是 mpv 日志里任意一条 level=error 的消息（音轨解码器报的也算）。
/// 之前一收到就盖全屏红框，于是出现「画面明明在播，中间顶着『这条解不开』」。
///
/// 这个测试锁住两条规则：
///   1. playing == true 时，无论 error 是什么，都不许盖遮罩
///   2. playing == false 时，才显示
void main() {
  final video = VideoItem(
    id: 'v1',
    path: r'C:\videos\a.mp4',
    name: 'a.mp4',
    folderId: 'f1',
    duration: 125000,
    addedAt: DateTime.now().millisecondsSinceEpoch,
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('正在播放时，错误不盖遮罩', (tester) async {
    await tester.pumpWidget(
      wrap(
        VideoStage(
          video: video,
          controller: null,
          playing: true,
          error: 'Error decoding audio.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('这条解不开'), findsNothing);
    expect(find.text('Error decoding audio.'), findsNothing);
  });

  testWidgets('没在播放时，错误要盖遮罩', (tester) async {
    await tester.pumpWidget(
      wrap(
        VideoStage(
          video: video,
          controller: null,
          playing: false,
          error: 'Failed to open file',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('这条解不开'), findsOneWidget);
    expect(find.text('Failed to open file'), findsOneWidget);
  });

  testWidgets('非致命提示只在角落显示，不挡画面', (tester) async {
    await tester.pumpWidget(
      wrap(
        VideoStage(
          video: video,
          controller: null,
          playing: true,
          notice: '这条视频的音轨解不开，已静音播放',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('这条视频的音轨解不开，已静音播放'), findsOneWidget);
    // 不是错误遮罩
    expect(find.text('这条解不开'), findsNothing);
  });

  testWidgets('没有错误时什么都不显示', (tester) async {
    await tester.pumpWidget(
      wrap(VideoStage(video: video, controller: null, playing: true)),
    );
    await tester.pump();

    expect(find.text('这条解不开'), findsNothing);
  });
}
