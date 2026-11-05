import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants.dart';
import '../core/paths.dart';

/// SQLite 连接管理
///
/// 桌面用 sqflite_common_ffi（sqflite 本身只支持移动端）。
/// schema v6，兼容手机版 v2~v5 的迁移路径，方便把手机 db 直接拷过来。
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    final d = _db;
    if (d != null) return d;
    return init();
  }

  Future<Database> init() async {
    if (_db != null) return _db!;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final path = AppPaths.dbPath;
    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppConstants.dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          // 播放中每 2 秒写进度 + 后台扫描批量入库会同时发生，
          // 手机版没开 WAL，桌面上容易 database is locked
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    // 老库（schema 已经是 v6 的）不会走 _onUpgrade，这里无条件补一次索引。
    // CREATE INDEX IF NOT EXISTS 在索引已存在时是空操作，开销可以忽略。
    await _ensureIndexes(_db!);
    return _db!;
  }

  /// 补齐可能缺失的索引
  ///
  /// 为什么不在 _onUpgrade 里做：那样必须提 schema 版本号，
  /// 而版本号一变就要写一堆迁移分支。索引是纯粹的加速结构，
  /// 每次启动检查一下最省事。
  Future<void> _ensureIndexes(Database db) async {
    const indexes = <String>[
      'CREATE INDEX IF NOT EXISTS idx_videos_addedAt ON videos(addedAt DESC)',
      'CREATE INDEX IF NOT EXISTS idx_videos_flags '
          'ON videos(isNotInterested, isFavorited, addedAt DESC)',
    ];
    for (final sql in indexes) {
      try {
        await db.execute(sql);
      } catch (_) {
        // 建索引失败不影响使用，只是慢一点
      }
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ────────────────────────── 建表 ──────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id            TEXT PRIMARY KEY,
        path          TEXT NOT NULL,
        name          TEXT NOT NULL,
        videoCount    INTEGER DEFAULT 0,
        addedAt       INTEGER NOT NULL,
        lastScannedAt INTEGER NOT NULL,
        autoScan      INTEGER DEFAULT 1,
        available     INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
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
        isTranscoded    INTEGER DEFAULT 0,
        FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_videos_folderId ON videos(folderId)');
    await db.execute('CREATE INDEX idx_videos_playCount ON videos(playCount)');
    await db.execute(
      'CREATE INDEX idx_videos_lastPlayedAt ON videos(lastPlayedAt)',
    );
    await db.execute('CREATE INDEX idx_videos_path ON videos(path)');
    await db.execute(
      'CREATE INDEX idx_videos_fingerprint ON videos(fileSize, fileMtime)',
    );
    // 推荐流按 addedAt DESC 取候选，2 万条没这个索引要全表排序
    await db.execute('CREATE INDEX idx_videos_addedAt ON videos(addedAt DESC)');
    // 推荐候选的过滤条件
    await db.execute(
      'CREATE INDEX idx_videos_flags ON videos(isNotInterested, isFavorited, addedAt DESC)',
    );

    await _createCommentsTable(db);
  }

  Future<void> _createCommentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comments (
        id             TEXT PRIMARY KEY,
        videoId        TEXT NOT NULL,
        content        TEXT NOT NULL,
        userName       TEXT NOT NULL,
        videoTimestamp INTEGER,
        createdAt      INTEGER NOT NULL,
        likeCount      INTEGER DEFAULT 0,
        isLiked        INTEGER DEFAULT 0,
        FOREIGN KEY (videoId) REFERENCES videos (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_comments_videoId ON comments(videoId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_comments_createdAt ON comments(createdAt)',
    );
  }

  // ────────────────────────── 迁移 ──────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 手机版 v2~v5 的原始迁移，原样保留，保证手机 db 能升上来
    if (oldVersion < 2) await _createCommentsTable(db);
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        'videos',
        'isFavorited',
        'INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await _addColumnIfMissing(
        db,
        'videos',
        'isNotInterested',
        'INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(
        db,
        'videos',
        'isNotInterested',
        'INTEGER DEFAULT 0',
      );
    }

    // v6：桌面版新增
    if (oldVersion < 6) {
      await _addColumnIfMissing(
        db,
        'videos',
        'resumePosition',
        'INTEGER DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'videos',
        'totalWatchMs',
        'INTEGER DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'videos', 'fileMtime', 'INTEGER DEFAULT 0');
      await _addColumnIfMissing(
        db,
        'folders',
        'available',
        'INTEGER DEFAULT 1',
      );

      // 用已有的比例回填断点位置，尽量不丢进度
      try {
        await db.rawUpdate(
          'UPDATE videos SET resumePosition = CAST(watchProgress * duration AS INTEGER) '
          'WHERE duration > 0 AND resumePosition = 0',
        );
      } catch (_) {}

      // 索引可能不存在（旧库）
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_videos_path ON videos(path)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_videos_fingerprint ON videos(fileSize, fileMtime)',
        );
      } catch (_) {}
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final exists = info.any((r) => r['name'] == column);
      if (exists) return;
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    } catch (_) {
      // 列已存在或表结构异常，忽略
    }
  }

  /// 完整性检查，损坏时备份并重建
  Future<bool> integrityOk() async {
    try {
      final d = await db;
      final r = await d.rawQuery('PRAGMA integrity_check');
      final v = r.isNotEmpty ? r.first.values.first?.toString() : '';
      return v == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<String?> backupCorrupted() async {
    try {
      final f = File(AppPaths.dbPath);
      if (!f.existsSync()) return null;
      final dst =
          '${AppPaths.dbPath}.corrupt.${DateTime.now().millisecondsSinceEpoch}';
      await f.copy(dst);
      return dst;
    } catch (_) {
      return null;
    }
  }
}
