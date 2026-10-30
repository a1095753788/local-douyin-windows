import 'dart:math';

import '../core/constants.dart';
import '../data/models/video_item.dart';
import '../data/repositories/video_repository.dart';

class _Scored {
  final VideoItem video;
  final double score;
  final WatchTier tier;
  _Scored(this.video, this.score, this.tier);
}

/// 观看档位 —— 推荐优先级的第一排序键
///
/// 为什么要单独分档，而不是只靠打分：
/// 一条「看完 + 点赞 + 播了 8 次」的老视频，分数可以轻松堆到 +20 以上；
/// 一条「从没播过」的新视频，如果只靠「从未播放 +10」这一项，
/// 根本压不住老视频。结果就是新视频永远排在后面，推荐流变成重播流。
///
/// 所以把「看没看过」提成硬约束：档位在前，分数只在档位内部决定顺序。
enum WatchTier {
  /// 从没播过（playCount == 0）—— 最优先
  unseen,

  /// 播过但没看完（20% ≤ 进度 < 90%）
  partial,

  /// 看完了（进度 ≥ 90%）—— 值得重看，但排在新片后面
  watched,

  /// 播过但基本划走了（进度 < 20%）—— 用户已经用脚投票，排最后
  skipped,
}

/// 推荐算法
///
/// 分两步走：
///   1. **分档**（[WatchTier]）：从没看过的 / 看了一部分的 / 看完的 / 划走的
///   2. **打分**：档位内部按分数排
///
/// 档位优先于分数，这是关键。手机版（以及本文件早期版本）只有分数，
/// 结果是一条「看完 + 点赞 + 播了 8 次」的老视频能堆到 +20 以上，
/// 而「从没播过」的新视频只有 +10，永远压不过老视频 —— 推荐流变成重播流。
///
/// 相比手机版修过的地方：
///   1. `clamp(5, len)` 在 len<5 时抛 ArgumentError → 改成先判断
///   2. `_recentlyShown` 只加不回收导致池枯竭 → 候选不足时清空重来
///   3. 删掉「收藏 +10」死代码（过滤层已排除收藏，永远走不到）
///   4. 新鲜度锚点用 min(addedAt, fileMtime)，否则首次全量导入时
///      所有老视频都 +20，信号失效
///   5. **进度 0 不再被当成「快速跳过 −10」** —— 新视频白扣 10 分是
///      「新视频永远排后面」的直接原因之一
///   6. **playCount 加分封顶 +3**，避免重度重播的老片挤掉新片
///   7. **分池改成「没看过的 / 看过的」**，15% 探索从「看过的」里翻，
///      保证看过的视频不会永远轮不到
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
        candidates
            .map((v) => _Scored(v, _computeScore(v, affinity), tierOf(v)))
            .toList()
          ..sort((a, b) {
            // 第一排序键：档位。没看过的永远排在看过的前面。
            final t = a.tier.index.compareTo(b.tier.index);
            if (t != 0) return t;
            // 同档位内才比分数
            return b.score.compareTo(a.score);
          });

    // 两堆。scored 已经排好序，过滤出来仍然有序。
    final freshPool = <_Scored>[
      for (final e in scored)
        if (e.tier == WatchTier.unseen) e,
    ];
    final stalePool = <_Scored>[
      for (final e in scored)
        if (e.tier != WatchTier.unseen) e,
    ];

    final result = <VideoItem>[];
    final usedIds = <String>{};
    String? lastFolder = lastFolderId;
    var consecutive = lastFolder == null ? 0 : 1;

    while (result.length < limit && usedIds.length < candidates.length) {
      // 默认从「没看过的」里挑。15% 概率去「看过的」堆里翻一条，
      // 免得看过的视频永远轮不到（用户可能想重看）。
      // 任一堆空了就自动落到另一堆。
      final useStale =
          stalePool.isNotEmpty &&
          (freshPool.isEmpty ||
              _random.nextDouble() < AppConstants.exploreEpsilon);
      final pool = useStale ? stalePool : freshPool;
      final other = useStale ? freshPool : stalePool;

      var picked = _pick(pool, usedIds, lastFolder, consecutive);

      // 多样性约束太严找不到 → 放宽
      picked ??= _pick(pool, usedIds, null, 0);

      // 本池找不到 → 换池
      picked ??= _pick(other, usedIds, null, 0);

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

  /// 判断一条视频属于哪个观看档位
  ///
  /// `watchProgress > 0` 也算「播过」：进度是播放时写回库的，
  /// 有进度说明一定播过，比 playCount 更不容易漏（playCount 有 3 秒阈值）。
  static WatchTier tierOf(VideoItem v) {
    final played = v.playCount > 0 || v.watchProgress > 0;
    if (!played) return WatchTier.unseen;

    final p = v.watchProgress;
    if (p >= AppConstants.watchedProgress) return WatchTier.watched;
    if (p < AppConstants.skippedProgress) return WatchTier.skipped;
    return WatchTier.partial;
  }

  double _computeScore(VideoItem v, Map<String, double> affinity) {
    var score = 0.0;

    // 1) 互动分
    if (v.isLiked) score += 2.0;
    // 收藏不加分：过滤层已经把收藏视频排除，这里是死代码，删掉
    // 播放次数封顶 +3：看 20 次和看 6 次不该有区别，
    // 否则重度重播的老片会把新片挤下去
    score += min(v.playCount * 0.5, 3.0);

    // 2) 观看进度（权重最大的信号）
    //
    // watchProgress == 0 有两种含义：
    //   a) 从没播过
    //   b) 播了但一秒都没看完
    // 原来的写法把 a 也当成「快速跳过 −10」，等于给所有新视频白扣 10 分，
    // 这是「新视频永远排后面」的直接原因之一。
    // 只有真的播过（playCount > 0）才评进度。
    if (v.playCount > 0) {
      final prog = v.watchProgress;
      if (prog < AppConstants.skippedProgress) {
        score -= 10.0; // 快速跳过
      } else if (prog < 0.5) {
        score += 2.0;
      } else if (prog < AppConstants.watchedProgress) {
        score += 5.0;
      } else {
        score += 15.0; // 基本看完
      }
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

    // 5) 「从未播放 +10」已删除：
    // 这件事现在由 WatchTier.unseen 硬性保证，比加分可靠得多。
    // 留着一个同层内的常数加分只会误导后来的人。

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
