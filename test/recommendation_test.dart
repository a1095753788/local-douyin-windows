import 'dart:math';

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

  test('看完的视频排在没看过的后面（分数更高）', () async {
    final old = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    final pool = <VideoItem>[
      // 都没播放过，但一个看完了（进度 95%），一个刚点开就划走（5%）
      fake(1, watchProgress: 0.95, addedAt: old),
      fake(2, watchProgress: 0.05, addedAt: old),
      // 加一批噪声，让排序真的有区分度
      for (var i = 3; i < 40; i++)
        fake(i, watchProgress: 0.05, playCount: 1, addedAt: old),
    ];
    // 关掉探索：把 epsilon 的影响交给统计（跑 20 次看平均名次）
    var sumRank = 0;
    const n = 20;
    for (var i = 0; i < n; i++) {
      final r = await svc(pool).recommend(limit: 40);
      sumRank += r.indexWhere((v) => v.id == 'v1');
    }
    final avg = sumRank / n;
    // ignore: avoid_print
    print('看完的那条平均名次：$avg / ${pool.length}');
    expect(avg, lessThan(pool.length / 3));
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

  test('explore 池真的会被用到（不是永远按分数取前 N）', () async {
    // 40 条：1 条高分，其余低分。纯 exploit 的话低分那条几乎不出现
    final pool = <VideoItem>[
      fake(0, watchProgress: 1.0, liked: true, playCount: 10),
      for (var i = 1; i < 40; i++) fake(i, watchProgress: 0.05, addedAt: 0),
    ];
    final hit = <String>{};
    for (var i = 0; i < 40; i++) {
      final r = await svc(pool).recommend(limit: 5);
      hit.addAll(r.map((v) => v.id));
    }
    // 探索率 15%，40 轮里应该能摸到不少低分的
    expect(hit.length, greaterThan(10));
    expect(max(1, hit.length), lessThanOrEqualTo(40));
  });
}
