class CommentItem {
  final String id;
  final String videoId;
  final String content;
  final String userName;

  /// 评论时视频所处的毫秒位置（手机版建了字段但没用；桌面版保留，
  /// 将来可做「按时间轴弹幕」）
  final int? videoTimestamp;

  final int createdAt;
  final int likeCount;
  final bool isLiked;

  const CommentItem({
    required this.id,
    required this.videoId,
    required this.content,
    this.userName = '本地用户',
    this.videoTimestamp,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
  });

  String get timeAgo {
    final diff = DateTime.now().millisecondsSinceEpoch - createdAt;
    final s = diff ~/ 1000;
    if (s < 60) return '刚刚';
    final m = s ~/ 60;
    if (m < 60) return '$m 分钟前';
    final h = m ~/ 60;
    if (h < 24) return '$h 小时前';
    final d = h ~/ 24;
    if (d < 30) return '$d 天前';
    if (d < 365) return '${d ~/ 30} 个月前';
    return '${d ~/ 365} 年前';
  }

  CommentItem copyWith({
    String? id,
    String? videoId,
    String? content,
    String? userName,
    int? videoTimestamp,
    int? createdAt,
    int? likeCount,
    bool? isLiked,
  }) {
    return CommentItem(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      content: content ?? this.content,
      userName: userName ?? this.userName,
      videoTimestamp: videoTimestamp ?? this.videoTimestamp,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'videoId': videoId,
    'content': content,
    'userName': userName,
    'videoTimestamp': videoTimestamp,
    'createdAt': createdAt,
    'likeCount': likeCount,
    'isLiked': isLiked ? 1 : 0,
  };

  factory CommentItem.fromMap(Map<String, Object?> m) {
    return CommentItem(
      id: m['id'] as String,
      videoId: m['videoId'] as String,
      content: (m['content'] as String?) ?? '',
      userName: (m['userName'] as String?) ?? '本地用户',
      videoTimestamp: m['videoTimestamp'] as int?,
      createdAt: (m['createdAt'] as int?) ?? 0,
      likeCount: (m['likeCount'] as int?) ?? 0,
      isLiked: (m['isLiked'] as int?) == 1,
    );
  }
}
