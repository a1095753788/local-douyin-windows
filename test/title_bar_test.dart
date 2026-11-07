import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin_win/core/constants.dart';
import 'package:local_douyin_win/core/theme.dart';
import 'package:local_douyin_win/widgets/title_bar.dart';

/// 自绘标题栏
///
/// 起因：用系统标题栏时，Windows 按「系统深浅色」决定标题文字颜色，
/// 应用是深色而系统是浅色 → 黑字白底块糊在深色条上，完全看不清，
/// 而且没法从 Flutter 里改。这几条测试锁住「不会再退回去」。
void main() {
  /// WCAG 相对亮度
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  double contrast(Color a, Color b) {
    final la = lum(a);
    final lb = lum(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  Widget harness({
    bool collapsed = false,
    void Function(TitleAction)? onAction,
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: AppTheme.bg,
        body: Align(
          alignment: Alignment.topLeft,
          child: AppTitleBar(
            collapsed: collapsed,
            onAction: onAction ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('标题文字和背景的对比度足够（这次要修的正是这个）', (tester) async {
    // 主文字 #F5F5F7 压在 #16161A 上
    final ratio = contrast(AppTheme.textPrimary, AppTheme.titleBar);
    expect(
      ratio,
      greaterThan(7),
      reason: '标题文字对比度只有 ${ratio.toStringAsFixed(2)}:1，看着会糊',
    );

    // 菜单 / 图标的次级灰也要过 AA（4.5:1）
    final sub = contrast(AppTheme.textSecondary, AppTheme.titleBar);
    expect(
      sub,
      greaterThan(4.5),
      reason: '次级文字对比度只有 ${sub.toStringAsFixed(2)}:1',
    );
  });

  testWidgets('四个菜单都在，图标按钮能点到', (tester) async {
    final hits = <TitleAction>[];
    await tester.pumpWidget(harness(onAction: hits.add));

    expect(find.text(AppConstants.appName), findsOneWidget);
    for (final label in <String>['编辑(E)', '窗口(W)', '帮助(H)', '关于(A)']) {
      expect(find.text(label), findsOneWidget, reason: '缺少菜单 $label');
    }

    await tester.tap(find.byTooltip('搜索 (跳到发现页)'));
    await tester.pump();
    expect(hits, contains(TitleAction.search));
  });

  testWidgets('编辑菜单展开后有添加文件夹 / 重扫', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('编辑(E)'));
    await tester.pumpAndSettle();

    expect(find.text('添加文件夹…'), findsOneWidget);
    expect(find.text('重新扫描全部'), findsOneWidget);
    expect(find.text('Ctrl+O'), findsOneWidget);
  });

  testWidgets('窗口菜单展开后有全屏和置顶', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('窗口(W)'));
    await tester.pumpAndSettle();

    expect(find.text('全屏'), findsOneWidget);
    expect(find.text('始终置顶'), findsOneWidget);
  });

  testWidgets('筛选图标展开五个条件', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();

    expect(find.text('没看过'), findsOneWidget);
    expect(find.text('点过赞'), findsOneWidget);
    expect(find.text('已收藏'), findsOneWidget);
  });

  testWidgets('最小窗口宽度 900 下不溢出', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final bar = tester.getSize(find.byType(AppTitleBar));
    expect(bar.width, 900);
    expect(bar.height, AppConstants.titleBarHeight);
  });

  testWidgets('折叠侧栏时第一个图标换成展开', (tester) async {
    await tester.pumpWidget(harness(collapsed: true));
    expect(find.byTooltip('展开侧栏'), findsOneWidget);

    await tester.pumpWidget(harness(collapsed: false));
    await tester.pumpAndSettle();
    expect(find.byTooltip('折叠侧栏'), findsOneWidget);
  });
}
