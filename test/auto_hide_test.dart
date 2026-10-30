import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/widgets/auto_hide.dart';

/// 全屏沉浸模式下控制层的显隐规则
///
/// 这几条是从主流播放器（DPlayer / YouTube / PotPlayer / MPC-BE）
/// 抄来的标准行为，锁住它们免得以后改坏：
///   1. 一开始显示
///   2. 静止 4 秒 → 隐藏
///   3. 鼠标一动 → 重新显示
///   4. 鼠标停在底部控制区 → 不隐藏
///   5. 暂停（forceShow）→ 一直显示
///   6. 非全屏（enabled=false）→ 一直显示
void main() {
  /// 记最后一次 builder 收到的 visible
  bool? last;

  Widget harness({
    bool enabled = true,
    bool forceShow = false,
    Duration hideAfter = const Duration(seconds: 4),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AutoHide(
          enabled: enabled,
          forceShow: forceShow,
          hideAfter: hideAfter,
          builder: (context, visible) {
            last = visible;
            // 必须撑满，否则 MouseRegion 尺寸为 0，鼠标根本进不来
            return const SizedBox.expand();
          },
        ),
      ),
    );
  }

  setUp(() => last = null);

  testWidgets('一开始就显示', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(last, isTrue);
  });

  testWidgets('静止 4 秒后隐藏', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(last, isTrue);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(last, isFalse, reason: '静止够久了，控制层应该藏起来');
  });

  testWidgets('鼠标一动就重新显示', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(last, isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(-100, -100));
    await tester.pump();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(240, 210));
    await tester.pump();

    expect(last, isTrue, reason: '鼠标动了却没反应，用户会以为卡住');
  });

  testWidgets('鼠标停在底部控制区时不隐藏', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(-100, -100));
    await tester.pump();
    addTearDown(mouse.removePointer);
    // 测试窗口逻辑尺寸 800x600，底部 150px 以内算控制区
    await mouse.moveTo(const Offset(400, 560));
    await tester.pump();

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(last, isTrue, reason: '鼠标正悬在进度条上，这时候消失很难受');
  });

  testWidgets('暂停时一直显示', (tester) async {
    await tester.pumpWidget(harness(forceShow: true));
    await tester.pump();

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(last, isTrue, reason: '暂停了还藏控制条，用户没法操作');
  });

  testWidgets('非全屏时永远显示', (tester) async {
    await tester.pumpWidget(harness(enabled: false));
    await tester.pump();

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(last, isTrue);
  });

  testWidgets('从播放切到暂停，已经藏起来的控制层要立刻回来', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(last, isFalse);

    await tester.pumpWidget(harness(forceShow: true));
    await tester.pump();

    expect(last, isTrue);
  });
}
