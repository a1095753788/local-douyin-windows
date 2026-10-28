import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/constants.dart';

class VideoMetadata {
  final int durationMs;
  final int width;
  final int height;
  final String container;
  final String videoCodec;

  const VideoMetadata({
    this.durationMs = 0,
    this.width = 0,
    this.height = 0,
    this.container = '',
    this.videoCodec = '',
  });

  bool get isEmpty => durationMs == 0 && width == 0;
}

/// FFmpeg 封装
///
/// 桌面版**不做转码**——libmpv 内部就是完整 FFmpeg，直接解所有格式。
/// 这里只负责两件跟播放无关的事：
///   1. 读元数据（时长/分辨率），比起播放器快一个数量级
///   2. 截缩略图，一个进程约 100ms，能并发
class FfmpegService {
  FfmpegService._();

  static String? _exe;
  static bool _resolved = false;

  /// 三级查找：内置 → PATH → 用户指定
  static Future<String?> locate({String? userOverride}) async {
    if (userOverride != null && userOverride.trim().isNotEmpty) {
      final f = File(userOverride);
      if (f.existsSync()) {
        _exe = f.path;
        _resolved = true;
        return _exe;
      }
    }
    if (_resolved) return _exe;

    // 1) 程序同目录下的 ffmpeg/
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      for (final name in <String>['ffmpeg.exe', 'ffmpeg']) {
        final f = File(p.join(exeDir, 'ffmpeg', name));
        if (f.existsSync()) {
          _exe = f.path;
          _resolved = true;
          return _exe;
        }
        final f2 = File(p.join(exeDir, name));
        if (f2.existsSync()) {
          _exe = f2.path;
          _resolved = true;
          return _exe;
        }
      }
    } catch (_) {}

    // 2) PATH
    try {
      final r = await Process.run('where', <String>[
        'ffmpeg',
      ], runInShell: true).timeout(const Duration(seconds: 5));
      if (r.exitCode == 0) {
        final first = (r.stdout as String)
            .split(RegExp(r'\r?\n'))
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
            .trim();
        if (first.isNotEmpty && File(first).existsSync()) {
          _exe = first;
          _resolved = true;
          return _exe;
        }
      }
    } catch (_) {}

    _exe = null;
    _resolved = true;
    return null;
  }

  static void reset() {
    _resolved = false;
    _exe = null;
  }

  static bool get isReady => _exe != null;

  static Future<bool> check(String exe) async {
    try {
      final r = await Process.run(exe, <String>[
        '-version',
      ]).timeout(const Duration(seconds: 8));
      return r.exitCode == 0 &&
          (r.stdout as String).toLowerCase().contains('ffmpeg');
    } catch (_) {
      return false;
    }
  }

  /// 读元数据
  ///
  /// `ffmpeg -i` 会把信息打到 stderr，格式二十年没变：
  ///   Duration: 00:01:23.45, start: ...
  ///   Stream #0:0: Video: h264 (High), yuv420p, 1920x1080 ...
  static Future<VideoMetadata> probe(String videoPath) async {
    final exe = _exe;
    if (exe == null) return const VideoMetadata();

    try {
      final r = await Process.run(exe, <String>[
        '-hide_banner',
        '-i',
        videoPath,
      ]).timeout(const Duration(seconds: 25));

      final text = '${r.stderr}\n${r.stdout}';
      return _parseProbe(text);
    } catch (_) {
      return const VideoMetadata();
    }
  }

  static VideoMetadata _parseProbe(String text) {
    var durationMs = 0;
    var width = 0;
    var height = 0;
    var container = '';
    var codec = '';

    final dur = RegExp(r'Duration:\s*(\d+):(\d{2}):(\d{2})\.(\d{1,3})')
        .firstMatch(text);
    if (dur != null) {
      final h = int.tryParse(dur.group(1)!) ?? 0;
      final m = int.tryParse(dur.group(2)!) ?? 0;
      final s = int.tryParse(dur.group(3)!) ?? 0;
      final frac = int.tryParse(dur.group(4)!.padRight(3, '0')) ?? 0;
      durationMs = ((h * 3600 + m * 60 + s) * 1000) + frac;
    }

    // 取第一个视频流的分辨率
    final vm = RegExp(r'Stream #\d+:\d+.*?: Video:\s*([A-Za-z0-9_\-]+)')
        .firstMatch(text);
    if (vm != null) codec = vm.group(1) ?? '';

    final res = RegExp(r'Video:.*?(\d{2,5})x(\d{2,5})').firstMatch(text);
    if (res != null) {
      width = int.tryParse(res.group(1)!) ?? 0;
      height = int.tryParse(res.group(2)!) ?? 0;
    }

    final fmt = RegExp(r'Input #0,\s*([^,]+),').firstMatch(text);
    if (fmt != null) container = (fmt.group(1) ?? '').trim();

    return VideoMetadata(
      durationMs: durationMs,
      width: width,
      height: height,
      container: container,
      videoCodec: codec,
    );
  }

  /// 截缩略图
  ///
  /// 不要截 0 秒——很多视频开头是黑场。
  ///
  /// 三级尝试：
  ///   1. 输入端快进到 10% 处（有索引的容器，最快）
  ///   2. 输入端快进到 1 秒（极短视频的兜底）
  ///   3. 输出端快进（慢，但 MPEG-TS / VOB 这类没索引的容器
  ///      输入端快进会直接失败，只能这么干）
  static Future<bool> thumbnail({
    required String videoPath,
    required String outputPath,
    int? durationMs,
  }) async {
    final exe = _exe;
    if (exe == null) return false;

    final dur = durationMs ?? 0;
    var seekMs = dur > 0
        ? (dur * AppConstants.thumbPositionRatio).round()
        : AppConstants.thumbPositionMinMs;
    seekMs = seekMs.clamp(
      AppConstants.thumbPositionMinMs,
      AppConstants.thumbPositionMaxMs,
    );

    final attempts = <({int seekMs, bool outputSeek})>[
      (seekMs: seekMs, outputSeek: false),
      (seekMs: 1000, outputSeek: false),
      // 输出端要真解码，压到 3 秒以内
      (seekMs: seekMs.clamp(500, 3000), outputSeek: true),
    ];

    for (final a in attempts) {
      final ok = await _runThumb(
        exe,
        videoPath,
        outputPath,
        a.seekMs,
        outputSeek: a.outputSeek,
      );
      if (ok) return true;
    }
    return false;
  }

  static Future<bool> _runThumb(
    String exe,
    String videoPath,
    String outputPath,
    int seekMs, {
    bool outputSeek = false,
  }) async {
    try {
      final outDir = Directory(p.dirname(outputPath));
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final seek = (seekMs / 1000).toStringAsFixed(3);
      final args = <String>[
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        if (!outputSeek) ...<String>['-ss', seek],
        '-i',
        videoPath,
        if (outputSeek) ...<String>['-ss', seek],
        '-frames:v',
        '1',
        '-vf',
        'scale=${AppConstants.thumbWidth}:-2',
        '-q:v',
        '${AppConstants.thumbQuality}',
        outputPath,
      ];

      final r = await Process.run(
        exe,
        args,
      ).timeout(const Duration(seconds: 45));

      if (r.exitCode != 0) return false;
      final f = File(outputPath);
      return f.existsSync() && f.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  /// 并发执行一批缩略图任务
  static Future<int> thumbnailBatch(
    List<({String video, String output, int durationMs})> tasks, {
    int concurrency = 4,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (tasks.isEmpty) return 0;
    var done = 0;
    var ok = 0;
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) return;
        final i = cursor++;
        if (i >= tasks.length) return;
        final t = tasks[i];
        final success = await thumbnail(
          videoPath: t.video,
          outputPath: t.output,
          durationMs: t.durationMs,
        );
        if (success) ok++;
        done++;
        onProgress?.call(done, tasks.length);
      }
    }

    final n = concurrency.clamp(1, 16);
    await Future.wait(List<Future<void>>.generate(n, (_) => worker()));
    return ok;
  }

  /// 读一行 ffmpeg 输出，用于调试
  static Future<String> version() async {
    final exe = _exe;
    if (exe == null) return 'ffmpeg 未找到';
    try {
      final r = await Process.run(exe, <String>[
        '-version',
      ]).timeout(const Duration(seconds: 8));
      final lines = LineSplitter.split(r.stdout as String).toList();
      return lines.isNotEmpty ? lines.first : '';
    } catch (e) {
      return '读取失败: $e';
    }
  }
}
