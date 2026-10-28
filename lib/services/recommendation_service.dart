import 'dart:math';

import '../core/constants.dart';
import '../data/models/video_item.dart';
import '../data/repositories/video_repository.dart';

class _Scored {
  final VideoItem video;
  final double score;
  _Scored(this.video, this.score);
}

/// 推荐算法
///
/// 公式与手机版完全一致，只修三处：
///   1. `clamp(5, len)` 在 len<5 时抛 ArgumentError → 改成先判断
///   2. `_recentlyShown` 只加不回收导致池枯竭 → 候选不足时清空重来
///   3. 删掉「收藏 +10」死代码（过滤层已排除收藏，永远走不到）
///
/// 另加一处语义修正：新鲜度锚点用 min(addedAt, fileMtime)，
/// 否则首次全量导入时所有老视频都 +20，信号失效。
class RecommendationService {
  /// 候选来源可注入——正常跑是查库，写测试时直接喂假数据。
  /// 打分/探索/多样性这套逻辑跟数据库无关，不该被它绑死。
  RecommendationService({Future<List<VideoItem>> Function()? candidatesLoader})
    : _load = candidatesLoader ?? VideoRepository().getCandidates;

  final Future<List<VideoItem>> Function() _load;
  final Random _random = Random();

  final List<String> _recentlyShown = <String>[];

  /// 本次会话已经推过的 id（短期去重）
  List<String> get recentlyShown => List.unmodifiable(_recentlyShown);

  void clearSessionMemory() => _recentlyShown.clear();

  Future<List<VideoItem>> recommend({
    int limit = 100,
    Set<String>? excludeIds,
    String? lastFolderId,
  }) async {
    final all = await _load(); // SQL 侧已排除不感兴趣 + 收藏
    if (all.isEmpty) return <VideoItem>[];

    final exclude = excludeIds ?? <String>{};

    List<VideoItem> filterCandidates() {
      return all.where((v) {
        if (exclude.contains(v.id)) return false;
        if (_recentlyShown.contains(v.id)) return false;
        return true;
      }).toList();
    }

    var candidates = filterCandidates();

    // 池枯竭保护：候选太少就清空会话记忆重来（允许重播，但仍打散顺序）
    if (candidates.length < AppConstants.minPoolSize) {
      _recentlyShown.clear();
      candidates = all.where((v) => !exclude.contains(v.id)).toList();
    }

    if (candidates.isEmpty) return <VideoItem>[];

    final affinity = _computeFolderAffinity(candidates);

    final scored =
        candidates.map((v) => _Scored(v, _computeScore(v, affinity))).toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    // 修 1：len <= 5 时不再 clamp（clamp 的 lower > upper 会抛异常）
    final cutIndex = scored.length <= 5
        ? scored.length
        : (scored.length * AppConstants.exploitRatio).round().clamp(
            5,
            scored.length,
          );

    final exploitPool = scored.take(cutIndex).toList();
    final explorePool = scored.skip(cutIndex).toList();

    final result = <VideoItem>[];
    final usedIds = <String>{};
    String? lastFolder = lastFolderId;
    var consecutive = lastFolder == null ? 0 : 1;

    while (result.length < limit && usedIds.length < candidates.length) {
      final isExplore =
          explorePool.isNotEmpty &&
          _random.nextDouble() < AppConstants.exploreEpsilon;
      final pool = isExplore ? explorePool : exploitPool;

      var picked = _pick(pool, usedIds, lastFolder, consecutive);

      // 多样性约束太严找不到 → 放宽
      picked ??= _pick(pool, usedIds, null, 0);

      // 本池找不到 → 换池
      picked ??= _pick(isExplore ? exploitPool : explorePool, usedIds, null, 0);

      if (picked == null) break;

      result.add(picked);
      usedIds.add(picked.id);

      if (picked.folderId == lastFolder) {
        consecutive++;
      } else {
        consecutive = 1;
        lastFolder = picked.folderId;
      }

      _recentlyShown.add(picked.id);
      while (_recentlyShown.length > AppConstants.recentlyShownLimit) {
        _recentlyShown.removeAt(0);
      }
    }

    return result;
  }

  /// 追加更多（无限流）
  Future<List<VideoItem>> recommendMore({
    required int limit,
    required List<VideoItem> existing,
  }) {
    final lastFolder = existing.isNotEmpty ? existing.last.folderId : null;
    return recommend(
      limit: limit,
      excludeIds: existing.map((v) => v.id).toSet(),
      lastFolderId: lastFolder,
    );
  }

  VideoItem? _pick(
    List<_Scored> pool,
    Set<String> usedIds,
    String? lastFolder,
    int consecutive,
  ) {
    for (final e in pool) {
      final v = e.video;
      if (usedIds.contains(v.id)) continue;
      if (_recentlyShown.contains(v.id)) continue;
      if (lastFolder != null &&
          v.folderId == lastFolder &&
          consecutive >= AppConstants.maxConsecutivePerFolder) {
        continue;
      }
      return v;
    }
    return null;
  }

  double _computeScore(VideoItem v, Map<String, double> affinity) {
    var score = 0.0;

    // 1) 互动分
    if (v.isLiked) score += 2.0;
    // 收藏不加分：过滤层已经把收藏视频排除，这里是死代码，删掉
    score += v.playCount * 0.5;

    // 2) 观看进度（权重最大的信号）
    final prog = v.watchProgress;
    if (prog < 0.2) {
      score -= 10.0; // 快速跳过
    } else if (prog < 0.5) {
      score += 2.0;
    } else if (prog < 0.9) {
      score += 5.0;
    } else {
      score += 15.0; // 基本看完
    }

    // 3) 新鲜度（锚点取 min(入库时间, 文件修改时间)）
    final now = DateTime.now().millisecondsSinceEpoch;
    final hours = (now - v.effectiveAddedAt) / 3600000.0;
    if (hours <= 24) {
      score += 20.0;
    } else if (hours <= 24 * 7) {
      score += 10.0;
    } else if (hours <= 24 * 30) {
      score += 5.0;
    }

    // 4) 文件夹亲和度 0~10
    score += affinity[v.folderId] ?? 0.0;

    // 5) 从未播放过
    if (v.playCount == 0) score += 10.0;

    // 6) 随机扰动 0~2，避免每次顺序一模一样
    score += _random.nextDouble() * 2.0;

    return score;
  }

  /// 文件夹亲和度：按该文件夹的平均播放热度归一化到 0~10
  Map<String, double> _computeFolderAffinity(List<VideoItem> candidates) {
    final play = <String, int>{};
    final watch = <String, double>{};
    final count = <String, int>{};

    for (final v in candidates) {
      play[v.folderId] = (play[v.folderId] ?? 0) + v.playCount;
      watch[v.folderId] = (watch[v.folderId] ?? 0) + v.watchProgress;
      count[v.folderId] = (count[v.folderId] ?? 0) + 1;
    }

    final raw = <String, double>{};
    var maxScore = 1.0;
    for (final id in count.keys) {
      final n = max(count[id] ?? 1, 1);
      final s = ((play[id] ?? 0) * 0.5 + (watch[id] ?? 0) * 2.0) / n;
      raw[id] = s;
      if (s > maxScore) maxScore = s;
    }

    final out = <String, double>{};
    for (final e in raw.entries) {
      out[e.key] = (e.value / maxScore) * 10.0;
    }
    return out;
  }
}
