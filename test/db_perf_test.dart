import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/data/models/video_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 数据库层基准：2 万条视频，各查询的真实耗时
///
///   flutter test test/db_perf_test.dart
const _createVideos = '''
CREATE TABLE videos (
  id              TEXT PRIMARY KEY,
  path            TEXT NOT NULL,
  name            TEXT NOT NULL,
  folderId        TEXT NOT NULL,
  fileSize        INTEGER DEFAULT 0,
  fileMtime       INTEGER DEFAULT 0,
  duration        INTEGER,
  width           INTEGER DEFAULT 0,
  height          INTEGER DEFAULT 0,
  thumbnailPath   TEXT,
  addedAt         INTEGER NOT NULL,
  lastPlayedAt    INTEGER NOT NULL,
  playCount       INTEGER DEFAULT 0,
  likeCount       INTEGER DEFAULT 0,
  isLiked         INTEGER DEFAULT 0,
  isFavorited     INTEGER DEFAULT 0,
  isNotInterested INTEGER DEFAULT 0,
  watchProgress   REAL DEFAULT 0.0,
  resumePosition  INTEGER DEFAULT 0,
  totalWatchMs    INTEGER DEFAULT 0,
  transcodedPath  TEXT,
  isTranscoded    INTEGER DEFAULT 0
)
''';

const _baseSelect = '''
  SELECT v.*, f.name AS folderName
  FROM videos v LEFT JOIN folders f ON v.folderId = f.id
''';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('基准：2 万条视频的查询耗时', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY, path TEXT NOT NULL, name TEXT NOT NULL,
        videoCount INTEGER DEFAULT 0, addedAt INTEGER NOT NULL,
        lastScannedAt INTEGER NOT NULL, autoScan INTEGER DEFAULT 1,
        available INTEGER DEFAULT 1
      )
    ''');
    await db.execute(_createVideos);

    // 8 个文件夹
    for (var f = 0; f < 8; f++) {
      await db.insert('folders', <String, Object?>{
        'id': 'f$f',
        'path': r'C:\videos\f$f',
        'name': '文件夹$f',
        'addedAt': 1,
        'lastScannedAt': 1,
      });
    }

    // 2 万条视频，批量插入
    const n = 20000;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < n; i++) {
        batch.insert('videos', <String, Object?>{
          'id': 'v$i',
          'path': r'C:\videos\f' '${i % 8}' r'\v$i.mp4',
          'name': 'v$i.mp4',
          'folderId': 'f${i % 8}',
          'fileSize': 1000 + i,
          'fileMtime': now - i * 1000,
          'duration': 60000,
          'addedAt': now - i * 1000,
          'lastPlayedAt': 0,
          'playCount': i % 7,
          'watchProgress': (i % 11) / 10.0,
        });
      }
      await batch.commit(noResult: true);
    });

    Future<void> time(String label, Future<void> Function() fn) async {
      final sw = Stopwatch()..start();
      await fn();
      sw.stop();
      // ignore: avoid_print
      print('$label → ${sw.elapsedMilliseconds}ms');
    }

    // 1) 现在的写法：无 LIMIT，无 addedAt 索引
    await time('当前 getCandidates（无 LIMIT、无索引）', () async {
      final rows = await db.rawQuery(
        '$_baseSelect WHERE v.isNotInterested = 0 AND v.isFavorited = 0 '
        'ORDER BY v.addedAt DESC',
      );
      final list = rows.map(VideoItem.fromMap).toList();
      if (list.length != n) throw StateError('条数不对: ${list.length}');
    });

    // 2) 只测 SQL，不含对象构造
    await time('  仅 SQL（不含 fromMap）', () async {
      await db.rawQuery(
        '$_baseSelect WHERE v.isNotInterested = 0 AND v.isFavorited = 0 '
        'ORDER BY v.addedAt DESC',
      );
    });

    // 3) 加索引后
    await db.execute('CREATE INDEX idx_videos_addedAt ON videos(addedAt DESC)');
    await db.execute(
      'CREATE INDEX idx_videos_flags '
      'ON videos(isNotInterested, isFavorited, addedAt DESC)',
    );
    await time('加索引后（仍无 LIMIT）', () async {
      final rows = await db.rawQuery(
        '$_baseSelect WHERE v.isNotInterested = 0 AND v.isFavorited = 0 '
        'ORDER BY v.addedAt DESC',
      );
      rows.map(VideoItem.fromMap).toList();
    });

    // 4) 现在的写法：索引 + LIMIT 5000
    await time('索引 + LIMIT 5000（当前写法）', () async {
      final rows = await db.rawQuery(
        '$_baseSelect WHERE v.isNotInterested = 0 AND v.isFavorited = 0 '
        'ORDER BY v.addedAt DESC LIMIT 5000',
      );
      final list = rows.map(VideoItem.fromMap).toList();
      if (list.length != 5000) throw StateError('条数不对: ${list.length}');
    });

    // 5) 统计（6 次全表扫描）
    await time('stats() 6 次 COUNT', () async {
      await db.rawQuery('SELECT COUNT(*) c FROM videos');
      await db.rawQuery('SELECT COUNT(*) c FROM videos WHERE isLiked = 1');
      await db.rawQuery('SELECT COUNT(*) c FROM videos WHERE isFavorited = 1');
      await db.rawQuery('SELECT COUNT(*) c FROM videos WHERE isNotInterested = 1');
      await db.rawQuery('SELECT SUM(playCount) c FROM videos');
      await db.rawQuery('SELECT COUNT(*) c FROM folders');
    });

    // 6) 统计合并成一次
    await time('stats() 合并成 1 次', () async {
      await db.rawQuery('''
        SELECT COUNT(*) total,
               SUM(isLiked = 1) liked,
               SUM(isFavorited = 1) fav,
               SUM(isNotInterested = 1) blocked,
               SUM(playCount) plays
        FROM videos
      ''');
    });

    await db.close();
  });
}
