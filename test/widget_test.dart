import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/core/constants.dart';

void main() {
  test('格式白名单包含手机版的 12 种 + 桌面新增的 27 种', () {
    expect(AppConstants.supportedVideoExtensions.length, 39);
    for (final ext in <String>['mp4', 'mkv', 'avi', 'rmvb', 'm2ts', 'vob']) {
      expect(AppConstants.isSupportedExtension(ext), isTrue, reason: ext);
    }
    expect(AppConstants.isSupportedExtension('MP4'), isTrue);
    expect(AppConstants.isSupportedExtension('txt'), isFalse);
  });

  test('推荐算法参数保持与手机版一致', () {
    expect(AppConstants.exploreEpsilon, 0.15);
    expect(AppConstants.maxConsecutivePerFolder, 2);
  });
}
