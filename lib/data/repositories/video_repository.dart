import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database.dart';
import '../models/video_item.dart';

/// 视频表的读写
///
/// 所有查询都 LEFT JOIN folders 拿到 folderName，
/// 修掉手机版界面上显示 UUID 的 bug。
class VideoRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  static const String _baseSelect = '''
    SELECT v.*, f.name AS folderName
    FROM videos v
    LEFT JOIN folders f ON v.folderId = f.id
  ''';

  Future<List<VideoItem>> getAll({String? orderBy}) async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect ORDER BY ${orderBy ?? 'v.lastPlayedAt DESC'}',
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  /// 推荐候选：SQL 侧先过滤掉不感兴趣和已收藏的
  Future<List<VideoItem>> getCandidates() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.isNotInterested = 0 AND v.isFavorited = 0 '
      'ORDER BY v.addedAt DESC',
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> getByFolder(String folderId) async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.folderId = ? ORDER BY v.name COLLATE NOCASE ASC',
      <Object?>[folderId],
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<VideoItem?> getById(String id) async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return VideoItem.fromMap(rows.first);
  }

  Future<List<VideoItem>> getFavorites() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.isFavorited = 1 AND v.isNotInterested = 0 '
      'ORDER BY v.lastPlayedAt DESC',
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> getLiked() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.isLiked = 1 AND v.isNotInterested = 0 '
      'ORDER BY v.lastPlayedAt DESC',
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> getNotInterested() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.isNotInterested = 1 ORDER BY v.name COLLATE NOCASE',
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> getMostPlayed({int limit = 100}) async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.isNotInterested = 0 '
      'ORDER BY v.playCount DESC, v.lastPlayedAt DESC LIMIT ?',
      <Object?>[limit],
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> getFresh({int limit = 100}) async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.isNotInterested = 0 AND v.playCount = 0 '
      'ORDER BY v.addedAt DESC LIMIT ?',
      <Object?>[limit],
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  /// 搜索 + 过滤（桌面版新增）
  Future<List<VideoItem>> search({
    String keyword = '',
    String? folderId,
    bool? liked,
    bool? favorited,
    bool? played,
    int minDurationMs = 0,
    int maxDurationMs = 0,
  }) async {
    final db = await _appDb.db;
    final where = <String>['v.isNotInterested = 0'];
    final args = <Object?>[];

    if (keyword.trim().isNotEmpty) {
      where.add('v.name LIKE ?');
      args.add('%${keyword.trim()}%');
    }
    if (folderId != null) {
      where.add('v.folderId = ?');
      args.add(folderId);
    }
    if (liked == true) where.add('v.isLiked = 1');
    if (favorited == true) where.add('v.isFavorited = 1');
    if (played == true) where.add('v.playCount > 0');
    if (played == false) where.add('v.playCount = 0');
    if (minDurationMs > 0) {
      where.add('v.duration >= ?');
      args.add(minDurationMs);
    }
    if (maxDurationMs > 0) {
      where.add('v.duration <= ?');
      args.add(maxDurationMs);
    }

    final rows = await db.rawQuery(
      '$_baseSelect WHERE ${where.join(' AND ')} '
      'ORDER BY v.lastPlayedAt DESC LIMIT 2000',
      args,
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  /// 扫描用：只拿 id/path/size/mtime，避免把整个对象读出来
  Future<Map<String, List<int>>> getPathFingerprints(String folderId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'videos',
      columns: <String>['path', 'fileSize', 'fileMtime'],
      where: 'folderId = ?',
      whereArgs: <Object?>[folderId],
    );
    final map = <String, List<int>>{};
    for (final r in rows) {
      map[r['path'] as String] = <int>[
        (r['fileSize'] as int?) ?? 0,
        (r['fileMtime'] as int?) ?? 0,
      ];
    }
    return map;
  }

  /// 换路径识别：size + mtime 相同但 path 不同的记录
  Future<VideoItem?> findByFingerprint(
    int size,
    int mtime,
    String exceptPath,
  ) async {
    if (size <= 0 || mtime <= 0) return null;
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.fileSize = ? AND v.fileMtime = ? AND v.path != ? LIMIT 1',
      <Object?>[size, mtime, exceptPath],
    );
    if (rows.isEmpty) return null;
    return VideoItem.fromMap(rows.first);
  }

  Future<void> insert(VideoItem v) async {
    final db = await _appDb.db;
    await db.insert(
      'videos',
      v.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBatch(List<VideoItem> list) async {
    if (list.isEmpty) return;
    final db = await _appDb.db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final v in list) {
        batch.insert(
          'videos',
          v.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> update(VideoItem v) async {
    final db = await _appDb.db;
    await db.update(
      'videos',
      v.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[v.id],
    );
  }

  Future<void> updatePath(String id, String newPath, String newName) async {
    final db = await _appDb.db;
    await db.update(
      'videos',
      <String, Object?>{'path': newPath, 'name': newName},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> updateThumbnail(String id, String? path) async {
    final db = await _appDb.db;
    await db.update(
      'videos',
      <String, Object?>{'thumbnailPath': path},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> updateMetadata(
    String id, {
    int? duration,
    int? width,
    int? height,
  }) async {
    final db = await _appDb.db;
    final values = <String, Object?>{};
    if (duration != null && duration > 0) values['duration'] = duration;
    if (width != null && width > 0) values['width'] = width;
    if (height != null && height > 0) values['height'] = height;
    if (values.isEmpty) return;
    await db.update(
      'videos',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 断点续播写回
  ///
  /// watchProgress 只增不减（历史最大），resumePosition 记本次位置，
  /// totalWatchMs 累加真实播放时长。
  Future<void> saveProgress(
    String id, {
    required int resumePosition,
    required double progress,
    int addWatchMs = 0,
  }) async {
    final db = await _appDb.db;
    await db.rawUpdate(
      'UPDATE videos SET '
      'resumePosition = ?, '
      'watchProgress = CASE WHEN ? > watchProgress THEN ? ELSE watchProgress END, '
      'totalWatchMs = totalWatchMs + ? '
      'WHERE id = ?',
      <Object?>[resumePosition, progress, progress, addWatchMs, id],
    );
  }

  Future<void> incrementPlayCount(String id) async {
    final db = await _appDb.db;
    await db.rawUpdate(
      'UPDATE videos SET playCount = playCount + 1, lastPlayedAt = ? WHERE id = ?',
      <Object?>[DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<void> toggleLike(String id) async {
    final db = await _appDb.db;
    await db.rawUpdate(
      'UPDATE videos SET '
      'likeCount = CASE WHEN isLiked = 1 THEN MAX(likeCount - 1, 0) ELSE likeCount + 1 END, '
      'isLiked = CASE WHEN isLiked = 1 THEN 0 ELSE 1 END '
      'WHERE id = ?',
      <Object?>[id],
    );
  }

  Future<void> toggleFavorite(String id) async {
    final db = await _appDb.db;
    await db.rawUpdate(
      'UPDATE videos SET isFavorited = CASE WHEN isFavorited = 1 THEN 0 ELSE 1 END WHERE id = ?',
      <Object?>[id],
    );
  }

  Future<void> toggleNotInterested(String id) async {
    final db = await _appDb.db;
    await db.rawUpdate(
      'UPDATE videos SET isNotInterested = CASE WHEN isNotInterested = 1 THEN 0 ELSE 1 END WHERE id = ?',
      <Object?>[id],
    );
  }

  Future<void> setNotInterested(String id, bool value) async {
    final db = await _appDb.db;
    await db.update(
      'videos',
      <String, Object?>{'isNotInterested': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> resetAllNotInterested() async {
    final db = await _appDb.db;
    return db.rawUpdate(
      'UPDATE videos SET isNotInterested = 0 WHERE isNotInterested = 1',
    );
  }

  Future<int> delete(String id) async {
    final db = await _appDb.db;
    return db.delete('videos', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<int> deleteByFolder(String folderId) async {
    final db = await _appDb.db;
    return db.delete(
      'videos',
      where: 'folderId = ?',
      whereArgs: <Object?>[folderId],
    );
  }

  Future<List<String>> getAllPaths() async {
    final db = await _appDb.db;
    final rows = await db.query('videos', columns: <String>['path']);
    return rows.map((r) => r['path'] as String).toList();
  }

  Future<List<VideoItem>> getVideosWithMissingThumbnail() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      // 注意：SQLite 里空字符串必须用单引号。
      // 用 "" 会被当成标识符，新版 SQLite（DQS 关闭）直接报
      // "no such column: """
      "$_baseSelect WHERE v.thumbnailPath IS NULL OR v.thumbnailPath = ''",
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> getVideosWithoutDuration() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.duration IS NULL OR v.duration <= 0',
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  // ── 统计 ──
  Future<Map<String, int>> stats() async {
    final db = await _appDb.db;
    final total = await db.rawQuery('SELECT COUNT(*) c FROM videos');
    final liked = await db.rawQuery(
      'SELECT COUNT(*) c FROM videos WHERE isLiked = 1',
    );
    final fav = await db.rawQuery(
      'SELECT COUNT(*) c FROM videos WHERE isFavorited = 1',
    );
    final blocked = await db.rawQuery(
      'SELECT COUNT(*) c FROM videos WHERE isNotInterested = 1',
    );
    final plays = await db.rawQuery('SELECT SUM(playCount) c FROM videos');
    final folders = await db.rawQuery('SELECT COUNT(*) c FROM folders');
    int v(List<Map<String, Object?>> r) =>
        (r.isNotEmpty ? (r.first['c'] as num?)?.toInt() : 0) ?? 0;
    return <String, int>{
      'videos': v(total),
      'liked': v(liked),
      'favorited': v(fav),
      'blocked': v(blocked),
      'plays': v(plays),
      'folders': v(folders),
    };
  }
}
