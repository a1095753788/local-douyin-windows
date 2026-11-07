import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/core/constants.dart';
import 'package:local_douyin_win/providers/player_provider.dart';

/// 倍速档位
///
/// 手机版只有 0.5~2.0，这里扩到 5.0。锁住三条容易被改坏的规则：
///   1. 档位表是升序、首尾等于 speedMin / speedMax
///   2. [ / ] 是「跳档」而不是「±0.1」（否则从 2.0 到 5.0 要按 30 次）
///   3. 越界值必须被夹住，不能把 8.0 传给 libmpv
void main() {
  test('档位表包含 3 / 4 / 5 倍且有序', () {
    final p = AppConstants.speedPresets;
    expect(p, contains(3.0));
    expect(p, contains(4.0));
    expect(p, contains(5.0));
    expect(p, contains(1.0));

    // 升序
    for (var i = 1; i < p.length; i++) {
      expect(p[i], greaterThan(p[i - 1]));
    }

    // 首尾与 min / max 一致，否则设置页滑块会越界
    expect(p.first, AppConstants.speedMin);
    expect(p.last, AppConstants.speedMax);
    expect(p.length, 9);
  });

  test('speedIndex 吸附到最近的档位', () {
    expect(AppConstants.speedIndex(1.0), 2);
    expect(AppConstants.speedIndex(5.0), 8);
    expect(AppConstants.speedIndex(0.5), 0);

    // 老版本存下来的非档位值
    expect(AppConstants.speedPresets[AppConstants.speedIndex(1.1)], 1.0);
    expect(AppConstants.speedPresets[AppConstants.speedIndex(1.9)], 2.0);
    expect(AppConstants.speedPresets[AppConstants.speedIndex(2.6)], 3.0);

    // 越界也不崩
    expect(AppConstants.speedIndex(99), 8);
    expect(AppConstants.speedIndex(0), 0);
  });

  test('nextSpeed 逐档跳，不会卡在中间值', () {
    // 从 2.0 一下就到 3.0，而不是 2.1
    expect(AppConstants.nextSpeed(2.0, 1), 3.0);
    expect(AppConstants.nextSpeed(3.0, 1), 4.0);
    expect(AppConstants.nextSpeed(4.0, 1), 5.0);
    expect(AppConstants.nextSpeed(1.0, 1), 1.25);

    // 反方向
    expect(AppConstants.nextSpeed(3.0, -1), 2.0);
    expect(AppConstants.nextSpeed(5.0, -1), 4.0);
    expect(AppConstants.nextSpeed(1.0, -1), 0.75);

    // 边界：到顶到底就停在原地，不越界
    expect(AppConstants.nextSpeed(5.0, 1), AppConstants.speedMax);
    expect(AppConstants.nextSpeed(0.5, -1), AppConstants.speedMin);

    // 非档位值也能正确跳到相邻档
    expect(AppConstants.nextSpeed(1.1, 1), 1.25);
    expect(AppConstants.nextSpeed(1.1, -1), 1.0);
    expect(AppConstants.nextSpeed(2.05, 1), 3.0);
  });

  test('nextSpeed 全档位走一遍不跳档、不回头', () {
    var s = AppConstants.speedMin;
    final seen = <double>[s];
    while (s < AppConstants.speedMax) {
      final n = AppConstants.nextSpeed(s, 1);
      expect(n, greaterThan(s));
      s = n;
      seen.add(s);
    }
    expect(seen, AppConstants.speedPresets);
  });

  test('formatSpeed 显示不带多余零', () {
    expect(AppConstants.formatSpeed(1.0), '1.0x');
    expect(AppConstants.formatSpeed(2.0), '2.0x');
    expect(AppConstants.formatSpeed(3.0), '3.0x');
    expect(AppConstants.formatSpeed(5.0), '5.0x');
    expect(AppConstants.formatSpeed(0.75), '0.75x');
    expect(AppConstants.formatSpeed(1.25), '1.25x');
    expect(AppConstants.formatSpeed(0.5), '0.5x');
    expect(AppConstants.formatSpeed(1.1), '1.1x');
  });

  test('setSpeed 把越界值夹在 0.5 ~ 5.0', () async {
    final p = PlayerProvider();
    await p.setSpeed(8.0);
    expect(p.speed, 5.0);
    await p.setSpeed(0.1);
    expect(p.speed, 0.5);
    await p.setSpeed(3.0);
    expect(p.speed, 3.0);
  });

  test('stepSpeed 从 2.0 一次到 3.0', () async {
    final p = PlayerProvider();
    await p.setSpeed(2.0);
    await p.stepSpeed(1);
    expect(p.speed, 3.0);
    await p.stepSpeed(1);
    expect(p.speed, 4.0);
    await p.stepSpeed(-1);
    expect(p.speed, 3.0);
  });
}
