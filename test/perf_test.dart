import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/data/models/video_item.dart';
import 'package:local_douyin_win/services/recommendation_service.dart';

/// 性能基准：候选池规模对推荐耗时的影响
///
/// 只在需要时手动跑：
///   flutter test test/perf_test.dart
VideoItem fake(int i, {String folder = 'f1', int addedAt = 0}) {
  return VideoItem(
    id: 'v$i',
    path: r'C:\v\v$i.mp4',
    name: 'v$i.mp4',
    folderId: folder,
    fileSize: 1000 + i,
    addedAt: addedAt == 0 ? DateTime.now().millisecondsSinceEpoch : addedAt,
    playCount: i % 7,
    watchProgress: (i % 11) / 10.0,
  );
}

void main() {
  test('基准：不同候选规模下的 recommend 耗时', () async {
    for (final n in <int>[500, 2000, 5000, 20000]) {
      final pool = <VideoItem>[
        for (var i = 0; i < n; i++) fake(i, folder: 'f${i % 8}'),
      ];

      // 预热一次，避免 JIT 干扰第一次
      await RecommendationService(candidatesLoader: () async => pool)
          .recommend(limit: 40);

      final sw = Stopwatch()..start();
      final r = await RecommendationService(
        candidatesLoader: () async => pool,
      ).recommend(limit: 40);
      sw.stop();

      // ignore: avoid_print
      print('候选 $n 条 → ${sw.elapsedMilliseconds}ms，返回 ${r.length} 条');
    }
  });

  test('基准：连续翻页 5 次（模拟刷到底加载更多）', () async {
    const n = 20000;
    final pool = <VideoItem>[
      for (var i = 0; i < n; i++) fake(i, folder: 'f${i % 8}'),
    ];
    final svc = RecommendationService(candidatesLoader: () async => pool);

    var feed = await svc.recommend(limit: 40);
    final sw = Stopwatch()..start();
    for (var page = 0; page < 5; page++) {
      final more = await svc.recommendMore(limit: 40, existing: feed);
      feed = <VideoItem>[...feed, ...more];
    }
    sw.stop();
    // ignore: avoid_print
    print('2 万条连续翻 5 页 → ${sw.elapsedMilliseconds}ms，累计 ${feed.length} 条');
  });
}
