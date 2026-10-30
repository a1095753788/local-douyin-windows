import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/core/constants.dart';
import 'package:local_douyin_win/data/models/video_item.dart';
import 'package:local_douyin_win/services/recommendation_service.dart';

VideoItem fake(
  int i, {
  String folder = 'f1',
  bool favorited = false,
  bool liked = false,
  bool notInterested = false,
  int playCount = 0,
  double watchProgress = 0,
  int addedAt = 0,
}) {
  return VideoItem(
    id: 'v$i',
    path:
        r'C:\v\v'
        '$i.mp4',
    name: 'v$i.mp4',
    folderId: folder,
    fileSize: 1000 + i,
    addedAt: addedAt == 0 ? DateTime.now().millisecondsSinceEpoch : addedAt,
    isFavorited: favorited,
    isLiked: liked,
    isNotInterested: notInterested,
    playCount: playCount,
    watchProgress: watchProgress,
  );
}

RecommendationService svc(List<VideoItem> pool) {
  // 模拟 SQL 过滤层：不感兴趣 + 已收藏 不进候选
  return RecommendationService(
    candidatesLoader: () async =>
        pool.where((v) => !v.isNotInterested && !v.isFavorited).toList(),
  );
}

void main() {
  test('候选少于 5 条时不抛异常（手机版这里会 ArgumentError）', () async {
    final s = svc(<VideoItem>[fake(1), fake(2), fake(3)]);
    final r = await s.recommend(limit: 10);
    expect(r.length, 3);
  });

  test('空库返回空列表', () async {
    final s = svc(<VideoItem>[]);
    expect(await s.recommend(), isEmpty);
  });

  test('收藏的视频永远不出现在推荐流里', () async {
    final pool = <VideoItem>[
      for (var i = 0; i < 30; i++) fake(i, favorited: i % 3 == 0),
    ];
    final s = svc(pool);
    final r = await s.recommend(limit: 100);
    expect(r.any((v) => v.isFavorited), isFalse);
    expect(r.length, 20); // 30 条里 10 条是收藏
  });

  test('不感兴趣的视频永远不出现', () async {
    final pool = <VideoItem>[
      for (var i = 0; i < 20; i++) fake(i, notInterested: i.isEven),
    ];
    final r = await svc(pool).recommend(limit: 100);
    expect(r.any((v) => v.isNotInterested), isFalse);
    expect(r.length, 10);
  });

  test('结果无重复', () async {
    final pool = <VideoItem>[for (var i = 0; i < 50; i++) fake(i)];
    final r = await svc(pool).recommend(limit: 50);
    expect(r.map((v) => v.id).toSet().length, r.length);
  });

  test('同一文件夹连续不超过 2 条', () async {
    // 3 个文件夹，足够多的量，跑多轮降低随机偶然
    for (var round = 0; round < 5; round++) {
      final pool = <VideoItem>[
        for (var i = 0; i < 90; i++) fake(i, folder: 'f${i % 3}'),
      ];
      final r = await svc(pool).recommend(limit: 60);
      var run = 1;
      for (var i = 1; i < r.length; i++) {
        if (r[i].folderId == r[i - 1].folderId) {
          run++;
          expect(
            run,
            lessThanOrEqualTo(AppConstants.maxConsecutivePerFolder),
            reason: '第 $i 条连续同文件夹超限',
          );
        } else {
          run = 1;
        }
      }
    }
  });

  test('从没看过的视频排在看完的前面（哪怕看完那条互动更好）', () async {
    final old = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    final pool = <VideoItem>[
      // 看完的老视频，而且点赞 + 播了 8 次，按老公式分数能堆到 +20 以上
      fake(1, watchProgress: 0.98, playCount: 8, liked: true, addedAt: old),
      // 从没播过的新视频，零互动零播放
      fake(2, addedAt: old),
      // 噪声：一堆「播过但划走」的
      for (var i = 3; i < 40; i++)
        fake(i, watchProgress: 0.05, playCount: 1, addedAt: old),
    ];

    var sumRank = 0;
    const n = 20;
    for (var i = 0; i < n; i++) {
      final r = await svc(pool).recommend(limit: 40);
      sumRank += r.indexWhere((v) => v.id == 'v2');
    }
    final avg = sumRank / n;
    // ignore: avoid_print
    print('没看过的那条平均名次：$avg / ${pool.length}');
    // 85% 的概率第一轮就挑到它，平均名次应该接近 0
    expect(avg, lessThan(2), reason: '没看过的视频没有排在最前面');
  });

  test('观看档位划分正确', () {
    expect(RecommendationService.tierOf(fake(1)), WatchTier.unseen);
    expect(
      RecommendationService.tierOf(fake(2, playCount: 1, watchProgress: 0.05)),
      WatchTier.skipped,
    );
    expect(
      RecommendationService.tierOf(fake(3, playCount: 1, watchProgress: 0.5)),
      WatchTier.partial,
    );
    expect(
      RecommendationService.tierOf(fake(4, playCount: 1, watchProgress: 0.95)),
      WatchTier.watched,
    );
    // 有进度但没 playCount（历史数据）也算播过，不能当新视频
    expect(
      RecommendationService.tierOf(fake(5, watchProgress: 0.95)),
      WatchTier.watched,
    );
  });

  test('全部看完时仍能正常出结果（freshPool 空不能崩）', () async {
    final pool = <VideoItem>[
      for (var i = 0; i < 30; i++)
        fake(i, watchProgress: 0.95, playCount: 2),
    ];
    final r = await svc(pool).recommend(limit: 30);
    expect(r.length, 30);
  });

  test('看过的视频仍有 15% 机会出现（不会永远轮不到）', () async {
    final pool = <VideoItem>[
      // 1 条看完的
      fake(0, watchProgress: 0.98, playCount: 5),
      // 39 条从没看过的
      for (var i = 1; i < 40; i++) fake(i),
    ];

    var hit = 0;
    const n = 40;
    for (var i = 0; i < n; i++) {
      final r = await svc(pool).recommend(limit: 3);
      if (r.any((v) => v.id == 'v0')) hit++;
    }
    // ignore: avoid_print
    print('看完的那条在 $n 轮里出现 $hit 次');
    // 15% 探索率，40 轮期望约 6 次
    expect(hit, greaterThanOrEqualTo(2), reason: '探索失效，看过的视频永远出不来');
  });

  test('池子小的时候反复调用不会锁死（手机版会永久 _noMore）', () async {
    final pool = <VideoItem>[for (var i = 0; i < 8; i++) fake(i)];
    final s = svc(pool);

    final seen = <String>{};
    for (var i = 0; i < 10; i++) {
      final r = await s.recommend(limit: 8);
      expect(r, isNotEmpty, reason: '第 $i 轮就空了');
      seen.addAll(r.map((v) => v.id));
    }
    expect(seen.length, 8);
  });

  test('同档位内分数低的也会被推出来（不是永远只出最高分）', () async {
    final old = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    // 全是「从没看过」的：1 条刚入库（+20 新鲜度），其余 39 条都是老片
    final pool = <VideoItem>[
      fake(0),
      for (var i = 1; i < 40; i++) fake(i, addedAt: old),
    ];
    final hit = <String>{};
    for (var i = 0; i < 40; i++) {
      final r = await svc(pool).recommend(limit: 5);
      hit.addAll(r.map((v) => v.id));
    }
    expect(hit.length, greaterThan(10), reason: '只出最高分那几条，低分的永远推不出来');
  });
}
