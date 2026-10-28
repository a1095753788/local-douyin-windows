import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/app_log.dart';
import '../core/constants.dart';
import '../core/paths.dart';
import '../data/models/folder_item.dart';
import '../data/models/video_item.dart';
import '../data/repositories/folder_repository.dart';
import '../data/repositories/video_repository.dart';
import '../platform/ffmpeg.dart';

class ScanProgress {
  final String folderId;
  final String folderName;
  final int scanned;
  final int total;
  final int added;
  final int updated;
  final int relocated;
  final int removed;
  final String currentFile;
  final bool finished;

  const ScanProgress({
    required this.folderId,
    required this.folderName,
    this.scanned = 0,
    this.total = 0,
    this.added = 0,
    this.updated = 0,
    this.relocated = 0,
    this.removed = 0,
    this.currentFile = '',
    this.finished = false,
  });

  double get fraction => total <= 0 ? 0 : (scanned / total).clamp(0.0, 1.0);
}

class ScanResult {
  final int added;
  final int removed;
  final int updated;
  final int relocated;
  final List<String> errors;

  const ScanResult({
    this.added = 0,
    this.removed = 0,
    this.updated = 0,
    this.relocated = 0,
    this.errors = const <String>[],
  });

  int get total => added + removed + updated + relocated;
}

/// 扫描服务
///
/// 与手机版的区别：
///   - 扫描只做「发现 + 入库」，秒级完成，缩略图后面异步补
///   - 查重从「只比 path」升级为「path + size + mtime 三元组」
///   - 支持识别「同一文件换了路径」（移动硬盘换盘符场景）
///   - 全程进度回调 + 可取消
class ScanService {
  final FolderRepository _folders = FolderRepository();
  final VideoRepository _videos = VideoRepository();
  final _uuid = const Uuid();

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// 添加文件夹（不扫描，扫描由调用方单独触发）
  Future<FolderItem> addFolder(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      throw Exception('文件夹不存在：$path');
    }
    final existing = await _folders.getByPath(path);
    if (existing != null) {
      throw Exception('这个文件夹已经添加过了');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final folder = FolderItem(
      id: _uuid.v4(),
      path: p.normalize(path),
      name: p.basename(path),
      addedAt: now,
      lastScannedAt: 0,
      autoScan: true,
      available: true,
    );
    await _folders.insert(folder);
    return folder;
  }

  /// 扫描单个文件夹
  Future<ScanResult> scanFolder(
    String folderId, {
    bool skipHidden = true,
    int minFileSizeKb = 0,
    bool deepScan = false,
    void Function(ScanProgress)? onProgress,
  }) async {
    _cancelled = false;

    final folder = await _folders.getById(folderId);
    if (folder == null) {
      return const ScanResult(errors: <String>['文件夹记录不存在']);
    }

    final dir = Directory(folder.path);
    if (!dir.existsSync()) {
      await _folders.setAvailable(folderId, false);
      return const ScanResult(errors: <String>['路径不存在']);
    }
    await _folders.setAvailable(folderId, true);

    // ── 1) 遍历收集候选文件 ──
    final found = <File>[];
    final errors = <String>[];
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (_cancelled) break;
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (skipHidden && name.startsWith('.')) continue;

        final ext = p
            .extension(entity.path)
            .replaceFirst('.', '')
            .toLowerCase();
        var accept = AppConstants.isSupportedExtension(ext);

        if (!accept && deepScan && ext.isNotEmpty) {
          // 深度扫描：白名单外的后缀跑一次 ffmpeg 探测
          final meta = await FfmpegService.probe(entity.path);
          accept = !meta.isEmpty;
        }
        if (!accept) continue;

        if (minFileSizeKb > 0) {
          try {
            if (entity.lengthSync() < minFileSizeKb * 1024) continue;
          } catch (_) {}
        }
        found.add(entity);
      }
    } catch (e) {
      errors.add('遍历失败：$e');
    }

    final total = found.length;
    onProgress?.call(
      ScanProgress(
        folderId: folderId,
        folderName: folder.displayName,
        total: total,
      ),
    );

    // ── 2) 与库内比对 ──
    final existing = await _videos.getPathFingerprints(folderId);
    final now = DateTime.now().millisecondsSinceEpoch;

    final toInsert = <VideoItem>[];
    var scanned = 0;
    var updated = 0;
    var relocated = 0;

    for (final f in found) {
      if (_cancelled) break;
      scanned++;

      int size = 0;
      int mtime = 0;
      try {
        final stat = f.statSync();
        size = stat.size;
        mtime = stat.modified.millisecondsSinceEpoch;
      } catch (_) {
        continue;
      }

      final normPath = p.normalize(f.path);
      final old = existing[normPath];

      if (old != null) {
        // 已存在：比对 size/mtime，变了就更新（覆盖过文件）
        if (old[0] != size || old[1] != mtime) {
          final item = await _findByPath(folderId, normPath);
          if (item != null) {
            await _videos.update(
              item.copyWith(
                fileSize: size,
                fileMtime: mtime,
                thumbnailPath: null, // 内容变了，缩略图作废
              ),
            );
            updated++;
          }
        }
        if (scanned % AppConstants.scanProgressEvery == 0) {
          onProgress?.call(
            ScanProgress(
              folderId: folderId,
              folderName: folder.displayName,
              scanned: scanned,
              total: total,
              added: toInsert.length,
              updated: updated,
              currentFile: p.basename(f.path),
            ),
          );
        }
        continue;
      }

      // 不在本文件夹的 path 集合里：可能是换了路径的同一文件
      final sameFile = await _videos.findByFingerprint(size, mtime, normPath);
      if (sameFile != null) {
        await _videos.updatePath(sameFile.id, normPath, p.basename(f.path));
        relocated++;
        continue;
      }

      toInsert.add(
        VideoItem(
          id: _uuid.v4(),
          path: normPath,
          name: p.basename(f.path),
          folderId: folderId,
          fileSize: size,
          fileMtime: mtime,
          addedAt: now,
          lastPlayedAt: 0,
        ),
      );

      if (scanned % AppConstants.scanProgressEvery == 0) {
        onProgress?.call(
          ScanProgress(
            folderId: folderId,
            folderName: folder.displayName,
            scanned: scanned,
            total: total,
            added: toInsert.length,
            updated: updated,
            currentFile: p.basename(f.path),
          ),
        );
      }
    }

    // ── 3) 批量入库 ──
    if (toInsert.isNotEmpty) {
      for (var i = 0; i < toInsert.length; i += AppConstants.scanBatchSize) {
        final end = (i + AppConstants.scanBatchSize).clamp(0, toInsert.length);
        await _videos.insertBatch(toInsert.sublist(i, end));
      }
    }

    // ── 4) 清理已不存在的记录 ──
    var removed = 0;
    if (!_cancelled) {
      final currentPaths = found.map((f) => p.normalize(f.path)).toSet();
      final dbVideos = await _videos.getByFolder(folderId);
      for (final v in dbVideos) {
        if (_cancelled) break;
        if (!currentPaths.contains(p.normalize(v.path))) {
          await _videos.delete(v.id);
          _deleteThumbFile(v.thumbnailPath);
          removed++;
        }
      }
    }

    await _folders.touchScanned(folderId);
    await _folders.refreshVideoCount(folderId);

    onProgress?.call(
      ScanProgress(
        folderId: folderId,
        folderName: folder.displayName,
        scanned: total,
        total: total,
        added: toInsert.length,
        removed: removed,
        finished: true,
      ),
    );

    return ScanResult(
      added: toInsert.length,
      removed: removed,
      updated: updated,
      relocated: relocated,
      errors: errors,
    );
  }

  Future<VideoItem?> _findByPath(String folderId, String path) async {
    final list = await _videos.getByFolder(folderId);
    for (final v in list) {
      if (p.normalize(v.path) == path) return v;
    }
    return null;
  }

  /// 扫描全部（autoScan 开着的）
  Future<ScanResult> scanAll({
    bool skipHidden = true,
    int minFileSizeKb = 0,
    bool deepScan = false,
    void Function(ScanProgress)? onProgress,
  }) async {
    final list = await _folders.getAll();
    var added = 0, removed = 0, updated = 0, relocated = 0;
    final errors = <String>[];

    for (final f in list) {
      if (_cancelled) break;
      if (!f.autoScan) continue;
      try {
        final r = await scanFolder(
          f.id,
          skipHidden: skipHidden,
          minFileSizeKb: minFileSizeKb,
          deepScan: deepScan,
          onProgress: onProgress,
        );
        added += r.added;
        removed += r.removed;
        updated += r.updated;
        relocated += r.relocated;
        errors.addAll(r.errors);
      } catch (e) {
        errors.add('${f.displayName}: $e');
      }
    }

    return ScanResult(
      added: added,
      removed: removed,
      updated: updated,
      relocated: relocated,
      errors: errors,
    );
  }

  /// 为缺少元数据的视频补时长/分辨率
  Future<int> fillMissingMetadata({
    void Function(int done, int total)? onProgress,
  }) async {
    final list = await _videos.getVideosWithoutDuration();
    var done = 0;
    for (final v in list) {
      if (_cancelled) break;
      final meta = await FfmpegService.probe(v.path);
      if (meta.durationMs > 0 || meta.width > 0) {
        await _videos.updateMetadata(
          v.id,
          duration: meta.durationMs,
          width: meta.width,
          height: meta.height,
        );
      }
      done++;
      onProgress?.call(done, list.length);
    }
    return done;
  }

  /// 为缺少缩略图的视频补缩略图
  Future<int> fillMissingThumbnails({
    Directory? thumbDir,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final list = await _videos.getVideosWithMissingThumbnail();
    AppLog.w('thumb', '待生成 ${list.length} 条');
    if (list.isEmpty) return 0;

    final tasks = <({String video, String output, int durationMs})>[];
    for (final v in list) {
      tasks.add((
        video: v.path,
        output: AppPaths.thumbPathFor(v.id, thumbDir),
        durationMs: v.duration ?? 0,
      ));
    }

    final concurrency = _defaultConcurrency();
    final ok = await FfmpegService.thumbnailBatch(
      tasks,
      concurrency: concurrency,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    AppLog.w('thumb', 'ffmpeg 成功 $ok / ${tasks.length}');
    // 把成功的路径写回库
    for (var i = 0; i < list.length; i++) {
      final out = tasks[i].output;
      if (File(out).existsSync()) {
        await _videos.updateThumbnail(list[i].id, out);
      }
    }
    return ok;
  }

  /// 删除单条（含缩略图；可选连文件）
  Future<void> deleteVideo(
    String videoId, {
    required bool deleteFile,
    bool toRecycleBin = true,
  }) async {
    final v = await _videos.getById(videoId);
    if (v == null) return;

    if (deleteFile) {
      final f = File(v.path);
      if (f.existsSync()) {
        if (toRecycleBin) {
          // 由调用方决定，这里默认直接删；回收站逻辑在 provider 层统一处理
          try {
            f.deleteSync();
          } catch (_) {}
        } else {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }

    _deleteThumbFile(v.thumbnailPath);
    await _videos.delete(videoId);
    await _folders.refreshVideoCount(v.folderId);
  }

  /// 删除整个文件夹（可选连文件）
  Future<void> deleteFolder(
    String folderId, {
    required bool deleteFiles,
  }) async {
    final folder = await _folders.getById(folderId);
    if (folder == null) return;

    final videos = await _videos.getByFolder(folderId);
    if (deleteFiles) {
      for (final v in videos) {
        final f = File(v.path);
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }
    for (final v in videos) {
      _deleteThumbFile(v.thumbnailPath);
    }
    await _folders.delete(folderId);
  }

  void _deleteThumbFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  static int _defaultConcurrency() {
    final cores = Platform.numberOfProcessors;
    return (cores ~/ 2).clamp(2, 8);
  }
}
