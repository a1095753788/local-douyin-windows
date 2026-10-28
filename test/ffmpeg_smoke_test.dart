import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/platform/ffmpeg.dart';

/// 这不是单元测试，是「手动体检」：
/// `flutter test test/ffmpeg_smoke_test.dart` 会真实调用 ffmpeg，
/// 用来确认三级查找 + 探测 + 截帧在本机可用。
void main() {
  test('ffmpeg 定位、探测、截帧', () async {
    final exe = await FfmpegService.locate();
    // ignore: avoid_print
    print('LOCATE => $exe');
    expect(exe, isNotNull, reason: '没找到 ffmpeg.exe');

    final v = r'H:\AI+\2026-10-28-15-41-06\probe_media\t_h264.mp4';
    final meta = await FfmpegService.probe(v);
    // ignore: avoid_print
    print(
      'PROBE => ${meta.durationMs}ms ${meta.width}x${meta.height} '
      '${meta.container} ${meta.videoCodec}',
    );
    expect(meta.durationMs, greaterThan(0));

    final out =
        '${Directory.systemTemp.path}${Platform.pathSeparator}smoke.jpg';
    final f = File(out);
    if (f.existsSync()) f.deleteSync();

    final ok = await FfmpegService.thumbnail(
      videoPath: v,
      outputPath: out,
      durationMs: meta.durationMs,
    );
    // ignore: avoid_print
    print('THUMB => $ok ${f.existsSync() ? f.lengthSync() : 0} bytes @ $out');
    expect(ok, isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
