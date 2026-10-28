import 'package:path/path.dart' as p;

class VideoItem {
  final String id;
  final String path;
  final String name;
  final String folderId;

  /// 文件夹名（不存库，查询时 JOIN 出来，用于界面显示）
  final String folderName;

  final int fileSize;

  /// 文件修改时间（毫秒）。用于增量扫描判断变化 + 新鲜度锚点
  final int fileMtime;

  /// 时长（毫秒），ffmpeg 解析不出来时为 null
  final int? duration;
  final int width;
  final int height;
  final String? thumbnailPath;

  final int addedAt; // 入库时间（毫秒）
  final int lastPlayedAt;

  final int playCount;
  final int likeCount;
  final bool isLiked;
  final bool isFavorited;
  final bool isNotInterested;

  /// 历史最大观看比例 0~1（只增不减），给推荐算法用
  final double watchProgress;

  /// 本次断点位置（毫秒），给续播用
  final int resumePosition;

  /// 累计观看毫秒（只累计 isPlaying 的时间）
  final int totalWatchMs;

  /// 手机版遗留字段，桌面版不写入，仅为兼容旧库保留
  final String? transcodedPath;
  final bool isTranscoded;

  const VideoItem({
    required this.id,
    required this.path,
    required this.name,
    required this.folderId,
    this.folderName = '',
    this.fileSize = 0,
    this.fileMtime = 0,
    this.duration,
    this.width = 0,
    this.height = 0,
    this.thumbnailPath,
    required this.addedAt,
    this.lastPlayedAt = 0,
    this.playCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.isFavorited = false,
    this.isNotInterested = false,
    this.watchProgress = 0,
    this.resumePosition = 0,
    this.totalWatchMs = 0,
    this.transcodedPath,
    this.isTranscoded = false,
  });

  /// 去掉扩展名的显示名
  String get displayName {
    final base = p.basenameWithoutExtension(name);
    return base.isEmpty ? name : base;
  }

  String get extension => p.extension(name).replaceFirst('.', '').toLowerCase();

  /// 实际播放路径（兼容手机版历史转码文件）
  String get playPath =>
      isTranscoded && transcodedPath != null && transcodedPath!.isNotEmpty
      ? transcodedPath!
      : path;

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get resolution => (width > 0 && height > 0) ? '${width}x$height' : '';

  String get durationText {
    if (duration == null || duration! <= 0) return '';
    final d = Duration(milliseconds: duration!);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// 新鲜度锚点：取「入库时间」和「文件修改时间」里更早的那个
  ///
  /// 手机版直接用 addedAt，导致首次全量导入时所有老视频都变成「刚加的」，
  /// 新鲜度 +20 对全部视频生效，信号失效。
  int get effectiveAddedAt {
    if (fileMtime > 0 && fileMtime < addedAt) return fileMtime;
    return addedAt;
  }

  bool get isPlayed => playCount > 0;

  bool get hasThumbnail => thumbnailPath != null && thumbnailPath!.isNotEmpty;

  VideoItem copyWith({
    String? id,
    String? path,
    String? name,
    String? folderId,
    String? folderName,
    int? fileSize,
    int? fileMtime,
    int? duration,
    int? width,
    int? height,
    String? thumbnailPath,
    int? addedAt,
    int? lastPlayedAt,
    int? playCount,
    int? likeCount,
    bool? isLiked,
    bool? isFavorited,
    bool? isNotInterested,
    double? watchProgress,
    int? resumePosition,
    int? totalWatchMs,
    String? transcodedPath,
    bool? isTranscoded,
  }) {
    return VideoItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      fileSize: fileSize ?? this.fileSize,
      fileMtime: fileMtime ?? this.fileMtime,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      isNotInterested: isNotInterested ?? this.isNotInterested,
      watchProgress: watchProgress ?? this.watchProgress,
      resumePosition: resumePosition ?? this.resumePosition,
      totalWatchMs: totalWatchMs ?? this.totalWatchMs,
      transcodedPath: transcodedPath ?? this.transcodedPath,
      isTranscoded: isTranscoded ?? this.isTranscoded,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'path': path,
    'name': name,
    'folderId': folderId,
    'fileSize': fileSize,
    'fileMtime': fileMtime,
    'duration': duration,
    'width': width,
    'height': height,
    'thumbnailPath': thumbnailPath,
    'addedAt': addedAt,
    'lastPlayedAt': lastPlayedAt,
    'playCount': playCount,
    'likeCount': likeCount,
    'isLiked': isLiked ? 1 : 0,
    'isFavorited': isFavorited ? 1 : 0,
    'isNotInterested': isNotInterested ? 1 : 0,
    'watchProgress': watchProgress,
    'resumePosition': resumePosition,
    'totalWatchMs': totalWatchMs,
    'transcodedPath': transcodedPath,
    'isTranscoded': isTranscoded ? 1 : 0,
  };

  factory VideoItem.fromMap(Map<String, Object?> m) {
    return VideoItem(
      id: m['id'] as String,
      path: m['path'] as String,
      name: m['name'] as String,
      folderId: (m['folderId'] as String?) ?? '',
      folderName: (m['folderName'] as String?) ?? '',
      fileSize: (m['fileSize'] as int?) ?? 0,
      fileMtime: (m['fileMtime'] as int?) ?? 0,
      duration: m['duration'] as int?,
      width: (m['width'] as int?) ?? 0,
      height: (m['height'] as int?) ?? 0,
      thumbnailPath: m['thumbnailPath'] as String?,
      addedAt: (m['addedAt'] as int?) ?? 0,
      lastPlayedAt: (m['lastPlayedAt'] as int?) ?? 0,
      playCount: (m['playCount'] as int?) ?? 0,
      likeCount: (m['likeCount'] as int?) ?? 0,
      isLiked: (m['isLiked'] as int?) == 1,
      isFavorited: (m['isFavorited'] as int?) == 1,
      isNotInterested: (m['isNotInterested'] as int?) == 1,
      watchProgress: (m['watchProgress'] as num?)?.toDouble() ?? 0,
      resumePosition: (m['resumePosition'] as int?) ?? 0,
      totalWatchMs: (m['totalWatchMs'] as int?) ?? 0,
      transcodedPath: m['transcodedPath'] as String?,
      isTranscoded: (m['isTranscoded'] as int?) == 1,
    );
  }

  @override
  String toString() =>
      'VideoItem($name, plays=$playCount, prog=$watchProgress)';
}
