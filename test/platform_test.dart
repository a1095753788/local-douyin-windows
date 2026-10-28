import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/core/paths.dart';
import 'package:local_douyin_win/platform/recycle_bin.dart';

void main() {
  test('移到回收站：文件从原位消失，返回成功计数', () {
    final f = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'recycle_probe_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    f.writeAsStringSync('本地抖音回收站自检');

    final r = RecycleBin.moveToTrash(<String>[f.path]);
    // ignore: avoid_print
    print('回收站 => ok=${r.ok} failed=${r.failed}');
    expect(r.ok, 1);
    expect(f.existsSync(), isFalse);
  });

  test('不存在的路径被安静跳过，不抛异常', () {
    final r = RecycleBin.moveToTrash(<String>[r'C:\__not_exists__\nope.mp4']);
    expect(r.ok, 0);
    expect(r.failed, isEmpty);
  });

  test('永久删除', () {
    final f = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'perm_probe_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    f.writeAsStringSync('x');
    final r = RecycleBin.deletePermanently(<String>[f.path]);
    expect(r.ok, 1);
    expect(f.existsSync(), isFalse);
  });

  test('字节格式化', () {
    expect(AppPaths.formatBytes(512), '512 B');
    expect(AppPaths.formatBytes(2048), '2.0 KB');
    expect(AppPaths.formatBytes(5 * 1024 * 1024), '5.0 MB');
  });
}
