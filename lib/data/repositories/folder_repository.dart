import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database.dart';
import '../models/folder_item.dart';

class FolderRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<List<FolderItem>> getAll() async {
    final db = await _appDb.db;
    final rows = await db.query('folders', orderBy: 'addedAt ASC');
    return rows.map(FolderItem.fromMap).toList();
  }

  Future<FolderItem?> getById(String id) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return FolderItem.fromMap(rows.first);
  }

  Future<FolderItem?> getByPath(String path) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'folders',
      where: 'path = ? COLLATE NOCASE',
      whereArgs: <Object?>[path],
    );
    if (rows.isEmpty) return null;
    return FolderItem.fromMap(rows.first);
  }

  Future<void> insert(FolderItem f) async {
    final db = await _appDb.db;
    await db.insert(
      'folders',
      f.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(FolderItem f) async {
    final db = await _appDb.db;
    await db.update(
      'folders',
      f.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[f.id],
    );
  }

  Future<void> setAutoScan(String id, bool value) async {
    final db = await _appDb.db;
    await db.update(
      'folders',
      <String, Object?>{'autoScan': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> setAvailable(String id, bool value) async {
    final db = await _appDb.db;
    await db.update(
      'folders',
      <String, Object?>{'available': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> touchScanned(String id) async {
    final db = await _appDb.db;
    await db.update(
      'folders',
      <String, Object?>{'lastScannedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 重算 videoCount
  Future<int> refreshVideoCount(String id) async {
    final db = await _appDb.db;
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM videos WHERE folderId = ?',
      <Object?>[id],
    );
    final count = (r.isNotEmpty ? (r.first['c'] as num?)?.toInt() : 0) ?? 0;
    await db.update(
      'folders',
      <String, Object?>{'videoCount': count},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return count;
  }

  Future<void> delete(String id) async {
    final db = await _appDb.db;
    // 外键已开 ON DELETE CASCADE，但显式删一次更保险（旧库可能没开外键）
    await db.delete('videos', where: 'folderId = ?', whereArgs: <Object?>[id]);
    await db.delete('folders', where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
