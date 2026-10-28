import 'package:flutter/foundation.dart';

import '../data/models/video_item.dart';
import '../data/repositories/comment_repository.dart';
import '../data/repositories/video_repository.dart';
import '../services/recommendation_service.dart';

/// 推荐流状态
///
/// 只负责「有哪些视频、当前第几条、某条被怎么操作了」。
/// 播放器相关的状态在 PlayerProvider，两者用 id 松耦合。
class VideoProvider extends ChangeNotifier {
  final VideoRepository _repo = VideoRepository();
  final CommentRepository _commentRepo = CommentRepository();
  final RecommendationService _rec = RecommendationService();

  List<VideoItem> _feed = <VideoItem>[];
  int _index = 0;
  bool _loading = false;
  String? _error;
  bool _exhausted = false;

  Map<String, int> _commentCounts = <String, int>{};

  List<VideoItem> _favorites = <VideoItem>[];
  bool _favLoading = false;

  Map<String, int> _stats = <String, int>{};

  // ── 只读 ──
  List<VideoItem> get feed => List<VideoItem>.unmodifiable(_feed);
  int get index => _index;
  int get feedLength => _feed.length;
  bool get loading => _loading;
  bool get exhausted => _exhausted;
  String? get error => _error;
  List<VideoItem> get favorites => List<VideoItem>.unmodifiable(_favorites);
  bool get favLoading => _favLoading;
  Map<String, int> get stats => Map<String, int>.unmodifiable(_stats);

  bool get hasFeed => _feed.isNotEmpty;

  VideoItem? get current =>
      (_index >= 0 && _index < _feed.length) ? _feed[_index] : null;

  int commentCountOf(String videoId) => _commentCounts[videoId] ?? 0;

  /// 当前这条在推荐流里的位置（给状态栏显示 3 / 40）
  String get positionText =>
      _feed.isEmpty ? '0 / 0' : '${_index + 1} / ${_feed.length}';

  // ────────────────────── 加载 ──────────────────────

  Future<void> loadFeed({int limit = 40}) async {
    _loading = true;
    _error = null;
    _exhausted = false;
    notifyListeners();

    try {
      _rec.clearSessionMemory();
      _feed = await _rec.recommend(limit: limit);
      _index = 0;
      await _reloadCommentCounts();
    } catch (e) {
      _error = '推荐流加载失败：$e';
      _feed = <VideoItem>[];
    }

    _loading = false;
    notifyListeners();
  }

  /// 无限流：走到尾部时补一批
  Future<void> appendMore({int limit = 20}) async {
    if (_loading || _exhausted) return;
    _loading = true;
    notifyListeners();
    try {
      final more = await _rec.recommendMore(limit: limit, existing: _feed);
      if (more.isEmpty) {
        _exhausted = true;
      } else {
        _feed = <VideoItem>[..._feed, ...more];
      }
    } catch (e) {
      _error = '加载更多失败：$e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _reloadCommentCounts() async {
    try {
      _commentCounts = await _commentRepo.countAll();
    } catch (_) {
      _commentCounts = <String, int>{};
    }
  }

  /// 单条评论数变化（新增/删除评论后由 CommentProvider 回调）
  void bumpCommentCount(String videoId, int delta) {
    final next = (_commentCounts[videoId] ?? 0) + delta;
    _commentCounts[videoId] = next < 0 ? 0 : next;
    notifyListeners();
  }

  // ────────────────────── 切换 ──────────────────────

  /// 下一条。返回是否真的移动了
  bool next() {
    if (_index >= _feed.length - 1) {
      // 到最后一条了，尝试补货，但这次仍返回 false（由调用方决定停还是等）
      if (!_exhausted && !_loading) unawaitedAppend();
      return false;
    }
    _index++;
    notifyListeners();
    return true;
  }

  bool prev() {
    if (_index <= 0) return false;
    _index--;
    notifyListeners();
    return true;
  }

  bool jumpTo(int i) {
    if (i < 0 || i >= _feed.length || i == _index) return false;
    _index = i;
    notifyListeners();
    return true;
  }

  /// 补货但不阻塞（避免 UI 卡住）
  void unawaitedAppend() {
    // ignore: discarded_futures
    appendMore();
  }

  // ────────────────────── 操作 ──────────────────────

  Future<VideoItem?> toggleLike(String videoId) async {
    await _repo.toggleLike(videoId);
    return _refreshOne(videoId);
  }

  Future<VideoItem?> toggleFavorite(String videoId) async {
    await _repo.toggleFavorite(videoId);
    final v = await _refreshOne(videoId);
    await loadFavorites();
    return v;
  }

  /// 不感兴趣：库里打标记 + 立即从当前流里摘掉
  Future<void> markNotInterested(String videoId) async {
    await _repo.setNotInterested(videoId, true);
    removeFromFeed(videoId);
    _stats = await _repo.stats();
    notifyListeners();
  }

  Future<void> undoNotInterested(String videoId) async {
    await _repo.setNotInterested(videoId, false);
    _stats = await _repo.stats();
    notifyListeners();
  }

  Future<int> resetNotInterested() async {
    final n = await _repo.resetAllNotInterested();
    _stats = await _repo.stats();
    notifyListeners();
    return n;
  }

  /// 把某条从当前流里移除（不删库）
  void removeFromFeed(String videoId) {
    final i = _feed.indexWhere((v) => v.id == videoId);
    if (i < 0) return;
    _feed = <VideoItem>[..._feed]..removeAt(i);
    if (_index >= _feed.length) _index = _feed.isEmpty ? 0 : _feed.length - 1;
    notifyListeners();
  }

  /// 从库里重新读一条，替换流里的旧对象
  Future<VideoItem?> _refreshOne(String videoId) async {
    final fresh = await _repo.getById(videoId);
    if (fresh == null) return null;
    final i = _feed.indexWhere((v) => v.id == videoId);
    if (i >= 0) {
      final copy = <VideoItem>[..._feed];
      copy[i] = fresh;
      _feed = copy;
    }
    notifyListeners();
    return fresh;
  }

  /// 播放器回调：播放计数 +1 了，需要同步界面上的次数
  Future<void> onPlayCounted(String videoId) async {
    await _refreshOne(videoId);
  }

  // ────────────────────── 收藏 ──────────────────────

  Future<void> loadFavorites() async {
    _favLoading = true;
    notifyListeners();
    try {
      _favorites = await _repo.getFavorites();
    } catch (_) {
      _favorites = <VideoItem>[];
    }
    _favLoading = false;
    notifyListeners();
  }

  /// 收藏页里取消收藏 → 直接从列表摘掉
  Future<void> removeFavorite(String videoId) async {
    await _repo.setNotInterested(videoId, false); // 确保没被误标
    await _repo.toggleFavorite(videoId);
    _favorites = _favorites.where((v) => v.id != videoId).toList();
    await _refreshOne(videoId);
    notifyListeners();
  }

  // ────────────────────── 统计 ──────────────────────

  Future<void> loadStats() async {
    _stats = await _repo.stats();
    notifyListeners();
  }

  /// 搜索（发现页用）
  Future<List<VideoItem>> search({
    String keyword = '',
    String? folderId,
    bool? liked,
    bool? favorited,
    bool? played,
  }) {
    return _repo.search(
      keyword: keyword,
      folderId: folderId,
      liked: liked,
      favorited: favorited,
      played: played,
    );
  }

  /// 扫描完成后刷新：推荐流重算 + 统计重算
  Future<void> onLibraryChanged() async {
    await loadStats();
    await _reloadCommentCounts();
    notifyListeners();
  }
}
