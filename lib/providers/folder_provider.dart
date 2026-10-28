import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/paths.dart';
import '../data/models/folder_item.dart';
import '../data/models/video_item.dart';
import '../data/repositories/folder_repository.dart';
import '../data/repositories/video_repository.dart';
import '../platform/ffmpeg.dart';
import '../platform/recycle_bin.dart';
import '../services/scan_service.dart';
import '../services/watch_service.dart';

/// 文件夹 + 扫描 + 缩略图 + 文件监视
class FolderProvider extends ChangeNotifier {
  final FolderRepository _repo = FolderRepository();
  final VideoRepository _videos = VideoRepository();
  final ScanService _scan = ScanService();
  final WatchService _watch = WatchService();

  List<FolderItem> _folders = <FolderItem>[];
  bool _loading = false;

  ScanProgress? _progress;
  bool _scanning = false;
  String? _lastScanSummary;

  bool _thumbRunning = false;
  int _thumbDone = 0;
  int _thumbTotal = 0;

  bool _watchEnabled = true;

  /// 扫描结束/文件变化后回调（由外部接上「刷新推荐流」）
  VoidCallback? onLibraryChanged;

  List<FolderItem> get folders => List<FolderItem>.unmodifiable(_folders);
  bool get loading => _loading;
  ScanProgress? get progress => _progress;
  bool get scanning => _scanning;
  String? get lastScanSummary => _lastScanSummary;
  bool get thumbRunning => _thumbRunning;
  int get thumbDone => _thumbDone;
  int get thumbTotal => _thumbTotal;

  int get totalVideos => _folders.fold<int>(0, (sum, f) => sum + f.videoCount);

  bool get ffmpegReady => FfmpegService.isReady;

  // ────────────────────── 加载 ──────────────────────

  Future<void> load({bool syncWatchers = true}) async {
    _loading = true;
    notifyListeners();
    try {
      _folders = await _repo.getAll();
      // 顺手标记一下路径是否还存在，界面要灰显
      var changed = false;
      final fixed = <FolderItem>[];
      for (final f in _folders) {
        final ok = Directory(f.path).existsSync();
        if (ok != f.available) {
          changed = true;
          await _repo.setAvailable(f.id, ok);
          fixed.add(f.copyWith(available: ok));
        } else {
          fixed.add(f);
        }
      }
      if (changed) _folders = fixed;
    } catch (_) {
      _folders = <FolderItem>[];
    }
    _loading = false;
    if (syncWatchers) applyWatchers(_watchEnabled);
    notifyListeners();
  }

  void applyWatchers(bool enabled) {
    _watchEnabled = enabled;
    _watch.onChanged = (folderId) {
      // 文件变化 → 增量扫描 → 通知上层刷新
      unawaited(scanOne(folderId));
    };
    _watch.sync(_folders, enabled: enabled);
  }

  void setWatchEnabled(bool enabled) {
    applyWatchers(enabled);
  }

  // ────────────────────── 添加 / 删除 ──────────────────────

  Future<FolderItem> addFolder(String path) async {
    final folder = await _scan.addFolder(path);
    await load();
    // 新加的直接扫一遍
    await scanOne(folder.id);
    return folder;
  }

  Future<void> removeFolder(
    String folderId, {
    bool deleteFiles = false,
    bool toRecycleBin = true,
  }) async {
    _watch.unwatch(folderId);

    if (deleteFiles) {
      final list = await _videos.getByFolder(folderId);
      final paths = list
          .map((v) => v.path)
          .where((e) => File(e).existsSync())
          .toList();
      if (paths.isNotEmpty) {
        if (toRecycleBin) {
          RecycleBin.moveToTrash(paths);
        } else {
          RecycleBin.deletePermanently(paths);
        }
      }
      for (final v in list) {
        _deleteThumb(v.thumbnailPath);
      }
    }

    await _repo.delete(folderId);
    await load();
    onLibraryChanged?.call();
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final f = await _repo.getById(folderId);
    if (f == null) return;
    await _repo.update(f.copyWith(name: newName));
    await load();
  }

  Future<void> toggleAutoScan(FolderItem f) async {
    await _repo.setAutoScan(f.id, !f.autoScan);
    await load();
  }

  // ────────────────────── 扫描 ──────────────────────

  Future<ScanResult> scanOne(
    String folderId, {
    bool skipHidden = true,
    int minFileSizeKb = 0,
    bool deepScan = false,
  }) async {
    if (_scanning) {
      return const ScanResult(errors: <String>['已有扫描在进行']);
    }
    _scanning = true;
    _lastScanSummary = null;
    notifyListeners();

    try {
      final r = await _scan.scanFolder(
        folderId,
        skipHidden: skipHidden,
        minFileSizeKb: minFileSizeKb,
        deepScan: deepScan,
        onProgress: (prog) {
          _progress = prog;
          notifyListeners();
        },
      );
      _lastScanSummary = _summary(r);
      await load();
      onLibraryChanged?.call();
      // 有新增/改动就补缩略图。文件监视触发的扫描同样要补，
      // 否则拖进来的新视频永远只有灰色占位图。
      if (r.added > 0 || r.updated > 0 || r.relocated > 0) {
        unawaited(generateMissingThumbnails());
      }
      return r;
    } finally {
      _scanning = false;
      _progress = null;
      notifyListeners();
    }
  }

  Future<ScanResult> scanAll({
    bool skipHidden = true,
    int minFileSizeKb = 0,
    bool deepScan = false,
  }) async {
    if (_scanning) {
      return const ScanResult(errors: <String>['已有扫描在进行']);
    }
    _scanning = true;
    _lastScanSummary = null;
    notifyListeners();

    try {
      final r = await _scan.scanAll(
        skipHidden: skipHidden,
        minFileSizeKb: minFileSizeKb,
        deepScan: deepScan,
        onProgress: (prog) {
          _progress = prog;
          notifyListeners();
        },
      );
      _lastScanSummary = _summary(r);
      await load();
      onLibraryChanged?.call();
      if (r.added > 0 || r.updated > 0 || r.relocated > 0) {
        unawaited(generateMissingThumbnails());
      }
      return r;
    } finally {
      _scanning = false;
      _progress = null;
      notifyListeners();
    }
  }

  void cancelScan() => _scan.cancel();

  String _summary(ScanResult r) {
    final parts = <String>[];
    if (r.added > 0) parts.add('新增 ${r.added}');
    if (r.updated > 0) parts.add('更新 ${r.updated}');
    if (r.relocated > 0) parts.add('换路径 ${r.relocated}');
    if (r.removed > 0) parts.add('移除 ${r.removed}');
    if (parts.isEmpty) parts.add('没有变化');
    if (r.errors.isNotEmpty) parts.add('${r.errors.length} 个错误');
    return parts.join(' · ');
  }

  // ────────────────────── 缩略图 ──────────────────────

  Future<void> generateMissingThumbnails() async {
    if (_thumbRunning) {
      AppLog.w('thumb', '已在运行，跳过');
      return;
    }
    if (!FfmpegService.isReady) {
      AppLog.w('thumb', 'ffmpeg 未就绪，跳过');
      return;
    }

    _thumbRunning = true;
    _thumbDone = 0;
    _thumbTotal = 0;
    notifyListeners();

    try {
      await _scan.fillMissingThumbnails(
        thumbDir: AppPaths.thumbDir,
        onProgress: (done, total) {
          _thumbDone = done;
          _thumbTotal = total;
          notifyListeners();
        },
        isCancelled: () => false,
      );
    } catch (e) {
      // 缩略图失败不影响主流程
      AppLog.w('thumb', '失败 $e');
    } finally {
      _thumbRunning = false;
      AppLog.w('thumb', '结束 done=$_thumbDone / $_thumbTotal');
      notifyListeners();
    }
  }

  /// 补元数据（时长/分辨率），给 ffmpeg 探测
  Future<int> fillMissingMetadata() async {
    if (!FfmpegService.isReady) return 0;
    final n = await _scan.fillMissingMetadata(
      onProgress: (done, total) {
        _thumbDone = done;
        _thumbTotal = total;
        notifyListeners();
      },
    );
    onLibraryChanged?.call();
    return n;
  }

  // ────────────────────── 删除单条 ──────────────────────

  /// 清掉「文件已经不在了」的记录
  ///
  /// 用户经常在资源管理器里直接删视频，库里就留下指向空气的记录，
  /// 推荐流刷到它只会报错。启动时扫一遍，只处理路径还在的文件夹
  /// ——移动硬盘没插的时候不能把整盘记录都删了。
  Future<int> pruneMissing() async {
    var removed = 0;
    try {
      final list = await _repo.getAll();
      for (final f in list) {
        if (!f.available) continue;
        final vids = await _videos.getByFolder(f.id);
        var hit = 0;
        for (final v in vids) {
          if (File(v.path).existsSync()) continue;
          _deleteThumb(v.thumbnailPath);
          await _videos.delete(v.id);
          hit++;
        }
        if (hit > 0) {
          await _repo.refreshVideoCount(f.id);
          removed += hit;
        }
      }
    } catch (e) {
      AppLog.w('prune', '失败 $e');
    }
    if (removed > 0) {
      AppLog.w('prune', '清掉 $removed 条失效记录');
      await load(syncWatchers: false);
    }
    return removed;
  }

  /// 删一条视频记录；deleteFile 为真时文件进回收站
  Future<void> deleteVideo(
    VideoItem v, {
    required bool deleteFile,
    bool toRecycleBin = true,
  }) async {
    if (deleteFile) {
      final f = File(v.path);
      if (f.existsSync()) {
        if (toRecycleBin) {
          RecycleBin.moveToTrash(<String>[v.path]);
        } else {
          RecycleBin.deletePermanently(<String>[v.path]);
        }
      }
    }
    _deleteThumb(v.thumbnailPath);
    await _videos.delete(v.id);
    await _repo.refreshVideoCount(v.folderId);
    await load(syncWatchers: false);
    onLibraryChanged?.call();
  }

  void _deleteThumb(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  // ────────────────────── 缓存清理 ──────────────────────

  /// 清理缩略图缓存
  Future<int> clearThumbCache() async {
    var freed = 0;
    try {
      if (AppPaths.thumbDir.existsSync()) {
        for (final e in AppPaths.thumbDir.listSync()) {
          if (e is File) {
            try {
              freed += e.lengthSync();
              e.deleteSync();
            } catch (_) {}
          }
        }
      }
      // 清空后把库里的路径也置空，下次会重新生成
      final all = await _videos.getVideosWithMissingThumbnail();
      // 已清空的那些其实路径还在库里，这里粗暴地把所有 thumbnailPath 清掉
      for (final v in all) {
        await _videos.updateThumbnail(v.id, null);
      }
      final rest = await _videos.getAll();
      for (final v in rest) {
        if (v.thumbnailPath != null && v.thumbnailPath!.isNotEmpty) {
          if (!File(v.thumbnailPath!).existsSync()) {
            await _videos.updateThumbnail(v.id, null);
          }
        }
      }
    } catch (_) {}
    return freed;
  }

  int get thumbCacheSize => AppPaths.dirSize(AppPaths.thumbDir);

  String get dbPath => AppPaths.dbPath;

  int get dbSize {
    try {
      final f = File(AppPaths.dbPath);
      return f.existsSync() ? f.lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// 文件名安全显示
  static String shortPath(String path, {int max = 60}) {
    if (path.length <= max) return path;
    final dir = p.dirname(path);
    final name = p.basename(path);
    final head = dir.length > max - name.length - 4
        ? '${dir.substring(0, (max - name.length - 8).clamp(0, dir.length))}…'
        : dir;
    return '$head\\$name';
  }

  @override
  void dispose() {
    _watch.dispose();
    super.dispose();
  }
}
