import 'dart:async';
import 'dart:convert';
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

/// 判断一个视频路径是不是网络视频源。
///
/// 网络视频的 path 是完整 http/https URL，由 libmpv 直接网络播放，
/// 不走任何本地文件检查（existsSync / ffmpeg 探测 / 回收站 / 缩略图落盘）。
bool isNetworkVideoPath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// 规范化用户填写的服务器地址：去首尾空白、去尾部斜杠、校验协议。
/// 抛出的 FormatException.message 可以直接显示给用户。
String normalizeNetworkServer(String input) {
  var s = input.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  final uri = Uri.tryParse(s);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw const FormatException(
      '服务器地址不正确，请填 http:// 或 https:// 开头的地址，例如 http://192.168.31.41:8765',
    );
  }
  return s;
}

/// 服务端 /api/videos.json 里一条视频解析后的纯数据。
class NetworkVideoEntry {
  final String url;
  final String name;
  final int size;
  final String folder;

  /// 秒级 Unix 时间戳
  final int mtime;

  const NetworkVideoEntry({
    required this.url,
    required this.name,
    required this.size,
    required this.folder,
    required this.mtime,
  });
}

/// 视频清单的解析结果。[server] 来自 JSON 顶层字段，为空时调用方用请求地址兜底。
class NetworkVideoManifest {
  final String server;
  final List<NetworkVideoEntry> videos;

  const NetworkVideoManifest({required this.server, required this.videos});
}

/// 解析 GET /api/videos.json 的响应体。
/// 格式错误抛 FormatException，message 为中文。
NetworkVideoManifest parseNetworkVideoManifest(String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    throw const FormatException('服务器返回的不是合法 JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('视频清单格式错误：顶层必须是 JSON 对象');
  }
  final rawVideos = decoded['videos'];
  if (rawVideos is! List) {
    throw const FormatException('视频清单格式错误：缺少 videos 数组');
  }

  final videos = <NetworkVideoEntry>[];
  for (final item in rawVideos) {
    if (item is! Map<String, dynamic>) continue;
    final rawUrl = item['url'];
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      throw const FormatException('视频清单格式错误：某条视频缺少 url');
    }
    final url = rawUrl.trim();

    var name = item['name'] is String ? (item['name'] as String).trim() : '';
    if (name.isEmpty) {
      final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
      name = segments.isEmpty ? url : segments.last;
    }

    final rawFolder = item['folder'];
    final folder = rawFolder is String ? rawFolder.trim() : '';
    if (folder.isEmpty) {
      throw const FormatException('视频清单格式错误：某条视频缺少 folder');
    }

    videos.add(
      NetworkVideoEntry(
        url: url,
        name: name,
        size: (item['size'] as num?)?.toInt() ?? 0,
        folder: folder,
        mtime: (item['mtime'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final rawServer = decoded['server'];
  return NetworkVideoManifest(
    server: rawServer is String ? rawServer.trim() : '',
    videos: videos,
  );
}

/// 按 folder 分组，保持服务端给出的顺序（Dart 的 Map 保持插入顺序）。
Map<String, List<NetworkVideoEntry>> groupNetworkVideosByFolder(
  List<NetworkVideoEntry> entries,
) {
  final grouped = <String, List<NetworkVideoEntry>>{};
  for (final e in entries) {
    (grouped[e.folder] ??= <NetworkVideoEntry>[]).add(e);
  }
  return grouped;
}

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

  /// 添加一个网络视频源：GET {server}/api/videos.json，按 folder 分组入库。
  ///
  /// 网络视频 id 直接用完整 URL（主键 TEXT，稳定）；FolderItem 用
  /// `net|server|folder` 作 id、`server/m/folder` 作 path，与本地文件夹隔离。
  /// 刷新时先按 folder 删旧记录再插入；同 URL 的旧记录带上收藏/进度/推荐状态，
  /// 避免刷新把用户数据冲掉。
  Future<FolderItem> addNetworkSource(String serverUrl) async {
    final inputServer = normalizeNetworkServer(serverUrl);
    final fetched = await _fetchNetworkVideos(inputServer);
    final grouped = groupNetworkVideosByFolder(fetched.videos);
    if (grouped.isEmpty) {
      throw Exception('服务器没有返回任何视频');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    FolderItem? first;
    for (final entry in grouped.entries) {
      final folder = await _writeNetworkFolder(
        server: fetched.server,
        folderName: entry.key,
        entries: entry.value,
        now: now,
      );
      first ??= folder;
    }
    return first!;
  }

  /// 刷新一个已入库的网络源（scanFolder 遇到网络目录时走这里）。
  Future<ScanResult> refreshNetworkFolder(String folderId) async {
    if (!folderId.startsWith('net|')) {
      return const ScanResult(errors: <String>['网络源记录无效']);
    }
    final raw = folderId.substring(4);
    final sep = raw.indexOf('|');
    if (sep <= 0) {
      return const ScanResult(errors: <String>['网络源记录无效']);
    }
    final server = raw.substring(0, sep);
    final folderName = raw.substring(sep + 1);
    try {
      final fetched = await _fetchNetworkVideos(server);
      final entries = fetched.videos
          .where((e) => e.folder == folderName)
          .toList(growable: false);
      await _writeNetworkFolder(
        server: fetched.server,
        folderName: folderName,
        entries: entries,
        now: DateTime.now().millisecondsSinceEpoch,
      );
      await _folders.touchScanned(folderId);
      await _folders.refreshVideoCount(folderId);
      return ScanResult(added: entries.length);
    } catch (e) {
      return ScanResult(errors: <String>['刷新网络源失败：$e']);
    }
  }

  Future<({String server, List<NetworkVideoEntry> videos})> _fetchNetworkVideos(
    String serverUrl,
  ) async {
    final uri = Uri.parse('$serverUrl/api/videos.json');
    // 用 dart:io 自带的 HttpClient，不引入第三方 http 包，
    // 避免新增依赖影响现有打包流程和原生库版本。
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    late final int statusCode;
    late final String responseBody;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 20));
      statusCode = response.statusCode;
      responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('连接服务器超时：$serverUrl');
    } catch (e) {
      throw Exception('连接服务器失败：$e');
    } finally {
      client.close(force: true);
    }
    if (statusCode != 200) {
      throw Exception('服务器返回 HTTP $statusCode，请检查服务是否正常');
    }
    try {
      final manifest = parseNetworkVideoManifest(responseBody);
      final server = manifest.server.isEmpty
          ? serverUrl
          : normalizeNetworkServer(manifest.server);
      return (server: server, videos: manifest.videos);
    } on FormatException catch (e) {
      throw Exception('视频清单格式错误：${e.message}');
    }
  }

  Future<FolderItem> _writeNetworkFolder({
    required String server,
    required String folderName,
    required List<NetworkVideoEntry> entries,
    required int now,
  }) async {
    final folderId = 'net|$server|$folderName';
    final folderPath = '$server/m/$folderName';

    // 刷新：先按 folder 删除旧记录再插入。
    // 同 URL 的旧记录带上收藏/进度/推荐状态，刷新不冲掉用户数据。
    final old = await _videos.getByFolder(folderId);
    final oldById = <String, VideoItem>{for (final v in old) v.id: v};
    await _videos.deleteByFolder(folderId);

    final items = <VideoItem>[];
    for (final e in entries) {
      final previous = oldById[e.url];
      final millis = e.mtime * 1000;
      items.add(
        previous != null
            ? previous.copyWith(
                path: e.url,
                name: e.name,
                folderId: folderId,
                fileSize: e.size,
                fileMtime: millis,
              )
            : VideoItem(
                id: e.url,
                path: e.url,
                name: e.name,
                folderId: folderId,
                fileSize: e.size,
                fileMtime: millis,
                addedAt: now,
              ),
      );
    }
    await _videos.insertBatch(items);

    final existing = await _folders.getById(folderId);
    final folder = FolderItem(
      id: folderId,
      path: folderPath,
      name: p.basename(folderName),
      videoCount: items.length,
      addedAt: existing?.addedAt ?? now,
      lastScannedAt: now,
      autoScan: existing?.autoScan ?? true,
      available: true,
    );
    await _folders.insert(folder);
    await _folders.refreshVideoCount(folderId);
    return folder;
  }

  /// 添加文件夹（不扫描，扫描由调用方单独触发）
  Future<FolderItem> addFolder(String path) async {
    if (isNetworkVideoPath(path)) {
      return addNetworkSource(path);
    }
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

    // 网络源不能当本地目录遍历，直接走网络刷新。
    if (isNetworkVideoPath(folder.path) || folderId.startsWith('net|')) {
      return refreshNetworkFolder(folderId);
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
            if (await entity.length() < minFileSizeKb * 1024) continue;
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
        // 用异步 stat。原来 statSync 在主 isolate 上跑，2 万个文件
        // 会把界面冻住将近一秒；异步版分散到 IO 线程池，界面全程可响应。
        final stat = await f.stat();
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
      // 别把网络视频误判成「换了路径的同一文件」
      if (sameFile != null && !isNetworkVideoPath(sameFile.path)) {
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
        if (isNetworkVideoPath(v.path)) continue; // 网络记录不在这里清理
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
    // 网络视频走不到本地文件，ffmpeg 探测会失败；元数据由播放时补
    final list = (await _videos.getVideosWithoutDuration())
        .where((v) => !isNetworkVideoPath(v.path))
        .toList();
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
    // 网络视频没有本地文件，跳过 ffmpeg 缩略图任务
    final list = (await _videos.getVideosWithMissingThumbnail())
        .where((v) => !isNetworkVideoPath(v.path))
        .toList();
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
    //
    // 原来是逐条 File.existsSync() + 逐条 UPDATE：2 万条要 2 万次同步 IO
    // 和 2 万次隐式事务，能卡好几分钟。改成 64 个一批并发检查 + 一次事务写回。
    const checkBatch = 64;
    final okMap = <String, String>{};
    for (var i = 0; i < list.length; i += checkBatch) {
      final end = (i + checkBatch).clamp(0, list.length);
      final slice = tasks.sublist(i, end);
      final exists = await Future.wait(
        slice.map((t) => File(t.output).exists()),
      );
      for (var j = 0; j < slice.length; j++) {
        if (exists[j]) okMap[list[i + j].id] = slice[j].output;
      }
    }
    await _videos.updateThumbnailBatch(okMap);
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

    // 网络视频只删数据库记录，不碰文件系统
    if (deleteFile && !isNetworkVideoPath(v.path)) {
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
        if (isNetworkVideoPath(v.path)) continue; // 网络视频只删记录
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
    if (isNetworkVideoPath(path)) return; // 网络视频没有本地缩略图文件
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
