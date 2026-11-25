import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/services/scan_service.dart';

/// 网络视频源的可测纯逻辑：URL 判定、地址规范化、JSON 解析、folder 分组。
/// 只测函数，不碰数据库和网络，因此不需要任何平台通道。
const String _sampleManifest = '''
{
  "server": "http://192.168.31.41:8765",
  "videos": [
    {"url": "http://192.168.31.41:8765/m/1630621300/video/a.mp4",
     "name": "a.mp4", "size": 123456,
     "folder": "1630621300/video", "mtime": 1700000000},
    {"url": "http://192.168.31.41:8765/m/1630621300/video/b.mp4",
     "name": "b.mp4", "size": 654321,
     "folder": "1630621300/video", "mtime": 1700000001},
    {"url": "https://cdn.example.com/m/other/c.mp4",
     "name": "c.mp4", "size": 999,
     "folder": "other", "mtime": 1700000002}
  ]
}
''';

void main() {
  group('网络视频路径判定', () {
    test('http / https 开头算网络视频', () {
      expect(isNetworkVideoPath('http://192.168.31.41:8765/m/a.mp4'), isTrue);
      expect(isNetworkVideoPath('https://example.com/a.mp4'), isTrue);
    });

    test('本地路径不算网络视频，协议必须小写', () {
      expect(isNetworkVideoPath(r'C:\videos\a.mp4'), isFalse);
      expect(isNetworkVideoPath('/home/me/a.mp4'), isFalse);
      expect(isNetworkVideoPath('HTTP://example.com/a.mp4'), isFalse);
    });
  });

  group('服务器地址规范化', () {
    test('去掉首尾空白与尾部斜杠', () {
      expect(
        normalizeNetworkServer('  http://192.168.31.41:8765/  '),
        'http://192.168.31.41:8765',
      );
      expect(
        normalizeNetworkServer('https://example.com/base///'),
        'https://example.com/base',
      );
    });

    test('非法地址抛中文格式异常', () {
      expect(
        () => normalizeNetworkServer('192.168.31.41:8765'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('http://'),
          ),
        ),
      );
    });
  });

  group('视频清单 JSON 解析', () {
    test('按固定格式解析出 server 与 videos', () {
      final manifest = parseNetworkVideoManifest(_sampleManifest);
      expect(manifest.server, 'http://192.168.31.41:8765');
      expect(manifest.videos, hasLength(3));

      final first = manifest.videos.first;
      expect(first.url, 'http://192.168.31.41:8765/m/1630621300/video/a.mp4');
      expect(first.name, 'a.mp4');
      expect(first.size, 123456);
      expect(first.folder, '1630621300/video');
      expect(first.mtime, 1700000000);
    });

    test('name / size / mtime 缺省时兜底', () {
      final manifest = parseNetworkVideoManifest('''
      {"server":"http://x","videos":[
        {"url":"http://x/m/f/only.mp4","folder":"f"}
      ]}
      ''');
      final v = manifest.videos.single;
      expect(v.name, 'only.mp4');
      expect(v.size, 0);
      expect(v.mtime, 0);
    });

    test('非法 JSON / 缺字段抛中文异常', () {
      expect(
        () => parseNetworkVideoManifest('not json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('不是合法 JSON'),
          ),
        ),
      );
      expect(
        () => parseNetworkVideoManifest('{"server":"x"}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('缺少 videos'),
          ),
        ),
      );
      expect(
        () =>
            parseNetworkVideoManifest('{"videos":[{"url":"http://x/a.mp4"}]}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('缺少 folder'),
          ),
        ),
      );
    });
  });

  group('按 folder 分组', () {
    test('同 folder 合并、保持服务端给出的顺序', () {
      final manifest = parseNetworkVideoManifest(_sampleManifest);
      final grouped = groupNetworkVideosByFolder(manifest.videos);

      expect(grouped.keys, <String>['1630621300/video', 'other']);
      expect(grouped['1630621300/video'], hasLength(2));
      expect(grouped['1630621300/video']!.map((e) => e.name).toList(), <String>[
        'a.mp4',
        'b.mp4',
      ]);
      expect(grouped['other']!.single.name, 'c.mp4');
    });

    test('生成的 folder id / path 与本地目录隔离', () {
      const server = 'http://192.168.31.41:8765';
      const folder = '1630621300/video';
      final id = 'net|$server|$folder';
      final path = '$server/m/$folder';

      expect(id, startsWith('net|'));
      expect(isNetworkVideoPath(path), isTrue);
      expect(id.contains(r'C:'), isFalse);
    });
  });
}
