import '../database.dart';
import '../models/comment_item.dart';

class CommentRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<List<CommentItem>> getByVideo(String videoId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'comments',
      where: 'videoId = ?',
      whereArgs: <Object?>[videoId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(CommentItem.fromMap).toList();
  }

  Future<int> countByVideo(String videoId) async {
    final db = await _appDb.db;
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM comments WHERE videoId = ?',
      <Object?>[videoId],
    );
    return (r.isNotEmpty ? (r.first['c'] as num?)?.toInt() : 0) ?? 0;
  }

  /// 一次查出所有视频的评论数，避免逐条 count
  Future<Map<String, int>> countAll() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      'SELECT videoId, COUNT(*) c FROM comments GROUP BY videoId',
    );
    final map = <String, int>{};
    for (final r in rows) {
      map[r['videoId'] as String] = (r['c'] as num).toInt();
    }
    return map;
  }

  Future<void> insert(CommentItem c) async {
    final db = await _appDb.db;
    await db.insert('comments', c.toMap());
  }

  Future<void> toggleLike(String id) async {
    final db = await _appDb.db;
    await db.rawUpdate(
      'UPDATE comments SET '
      'likeCount = CASE WHEN isLiked = 1 THEN MAX(likeCount - 1, 0) ELSE likeCount + 1 END, '
      'isLiked = CASE WHEN isLiked = 1 THEN 0 ELSE 1 END '
      'WHERE id = ?',
      <Object?>[id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    await db.delete('comments', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> deleteByVideo(String videoId) async {
    final db = await _appDb.db;
    await db.delete(
      'comments',
      where: 'videoId = ?',
      whereArgs: <Object?>[videoId],
    );
  }
}
