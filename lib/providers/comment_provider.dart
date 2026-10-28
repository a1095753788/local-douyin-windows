import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/comment_item.dart';
import '../data/repositories/comment_repository.dart';

/// 评论 / 弹幕
///
/// 「弹幕」和「评论」是同一份数据：带 videoTimestamp 的评论
/// 会在播放到那个时间点时从画面上飘过。
class CommentProvider extends ChangeNotifier {
  final CommentRepository _repo = CommentRepository();
  final _uuid = const Uuid();

  List<CommentItem> _comments = <CommentItem>[];
  String? _videoId;
  bool _loading = false;

  List<CommentItem> get comments => List<CommentItem>.unmodifiable(_comments);
  String? get videoId => _videoId;
  bool get loading => _loading;
  int get count => _comments.length;

  /// 只有带时间戳的才能当弹幕
  List<CommentItem> get danmakuPool =>
      _comments.where((c) => c.videoTimestamp != null).toList();

  /// 评论条数变化回调（让 VideoProvider 同步角标）
  void Function(String videoId, int delta)? onCountChanged;

  Future<void> load(String videoId) async {
    if (_videoId == videoId && _comments.isNotEmpty) return;
    _videoId = videoId;
    _loading = true;
    notifyListeners();
    try {
      _comments = await _repo.getByVideo(videoId);
    } catch (_) {
      _comments = <CommentItem>[];
    }
    _loading = false;
    notifyListeners();
  }

  /// 发表评论。带 timestamp 时同时是弹幕。
  Future<CommentItem?> add(
    String videoId,
    String content, {
    int? timestampMs,
  }) async {
    final text = content.trim();
    if (text.isEmpty) return null;

    final item = CommentItem(
      id: _uuid.v4(),
      videoId: videoId,
      content: text,
      userName: '我',
      videoTimestamp: timestampMs,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repo.insert(item);

    if (_videoId == videoId) {
      _comments = <CommentItem>[..._comments, item];
      notifyListeners();
    }
    onCountChanged?.call(videoId, 1);
    return item;
  }

  Future<void> toggleLike(String commentId) async {
    await _repo.toggleLike(commentId);
    final i = _comments.indexWhere((c) => c.id == commentId);
    if (i >= 0) {
      final c = _comments[i];
      final copy = <CommentItem>[..._comments];
      copy[i] = c.copyWith(
        isLiked: !c.isLiked,
        likeCount: c.isLiked
            ? (c.likeCount - 1).clamp(0, 1 << 30)
            : c.likeCount + 1,
      );
      _comments = copy;
      notifyListeners();
    }
  }

  Future<void> delete(String commentId) async {
    final i = _comments.indexWhere((c) => c.id == commentId);
    if (i < 0) return;
    final vid = _comments[i].videoId;
    await _repo.delete(commentId);
    _comments = <CommentItem>[..._comments]..removeAt(i);
    notifyListeners();
    onCountChanged?.call(vid, -1);
  }

  void clear() {
    _comments = <CommentItem>[];
    _videoId = null;
    notifyListeners();
  }
}
