import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// 标题栏上的动作
///
/// 这个 widget 只管「长什么样 + 点了哪个」，具体做什么交给外层。
/// 好处是标题栏不依赖任何 Provider，测试里塞个回调就能跑。
enum TitleAction {
  toggleSidebar,
  search,
  filterAll,
  filterUnplayed,
  filterPlayed,
  filterLiked,
  filterFavorited,
  addFolder,
  rescan,
  reshuffle,
  openSettings,
  toggleFullscreen,
  minimize,
  toggleMaximize,
  toggleAlwaysOnTop,
  shortcuts,
  openDataDir,
  openLog,
  openRepo,
  about,
  licenses,
}

/// 自绘标题栏
///
/// 为什么不用系统标题栏：Windows 的标题栏文字颜色跟着「系统深浅色」走，
/// 应用是深色而系统是浅色时，标题会变成「黑字 + 白底块」糊在深色条上，
/// 也就是之前那个看不清的样子。系统标题栏的配色没法从 Flutter 里可靠地改，
/// 干脆整条自己画。
///
/// 布局照抄主流桌面播放器：左边 logo + 名字，一排图标，一排菜单，
/// 右边三个窗口按钮。中间的空白区域用来拖动窗口。
class AppTitleBar extends StatefulWidget {
  /// 侧栏是否折叠（决定第一个图标长什么样）
  final bool collapsed;
  final void Function(TitleAction action) onAction;

  const AppTitleBar({
    super.key,
    required this.collapsed,
    required this.onAction,
  });

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _maximized = false;
  bool _onTop = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // ignore: discarded_futures
    _sync();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// 窗口状态只有原生侧知道，启动时问一次
  Future<void> _sync() async {
    try {
      final m = await windowManager.isMaximized();
      final t = await windowManager.isAlwaysOnTop();
      if (!mounted) return;
      setState(() {
        _maximized = m;
        _onTop = t;
      });
    } catch (_) {
      // 单元测试里没有原生通道，忽略即可
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> _toggleOnTop() async {
    final v = await windowManager.isAlwaysOnTop();
    await windowManager.setAlwaysOnTop(!v);
    if (mounted) setState(() => _onTop = !v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.titleBarHeight,
      decoration: const BoxDecoration(
        color: AppTheme.titleBar,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: <Widget>[
          // 左：logo + 名字。这一块可拖动、双击最大化。
          DragToMoveArea(child: _brand()),

          _IconButton(
            icon: widget.collapsed
                ? Icons.menu_rounded
                : Icons.vertical_split_rounded,
            tooltip: widget.collapsed ? '展开侧栏' : '折叠侧栏',
            onTap: () => widget.onAction(TitleAction.toggleSidebar),
          ),
          _IconButton(
            icon: Icons.search_rounded,
            tooltip: '搜索 (跳到发现页)',
            onTap: () => widget.onAction(TitleAction.search),
          ),
          _IconButton(
            icon: Icons.filter_alt_outlined,
            tooltip: '筛选',
            onSelected: widget.onAction,
            popupBuilder: _filterMenu,
          ),

          const _Sep(),

          _MenuButton(
            label: '编辑(E)',
            buildItems: _editMenu,
            onSelected: widget.onAction,
          ),
          _MenuButton(
            label: '窗口(W)',
            buildItems: _windowMenu,
            onSelected: widget.onAction,
          ),
          _MenuButton(
            label: '帮助(H)',
            buildItems: _helpMenu,
            onSelected: widget.onAction,
          ),
          _MenuButton(
            label: '关于(A)',
            buildItems: _aboutMenu,
            onSelected: widget.onAction,
          ),

          // 中间的空白：拖动窗口用
          Expanded(child: DragToMoveArea(child: const SizedBox.expand())),

          _WindowButton(
            glyph: _Glyph.minimize,
            onTap: () => windowManager.minimize(),
          ),
          _WindowButton(
            glyph: _maximized ? _Glyph.restore : _Glyph.maximize,
            onTap: _toggleMaximize,
          ),
          _WindowButton(
            glyph: _Glyph.close,
            danger: true,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }

  Widget _brand() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFE2C55), Color(0xFFFF6B81)],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────── 菜单内容 ──────────────────────

  List<PopupMenuEntry<TitleAction>> _filterMenu(BuildContext context) {
    return _items(const <_Entry?>[
      (label: '全部', hint: null, action: TitleAction.filterAll),
      (label: '没看过', hint: null, action: TitleAction.filterUnplayed),
      (label: '看过', hint: null, action: TitleAction.filterPlayed),
      (label: '点过赞', hint: null, action: TitleAction.filterLiked),
      (label: '已收藏', hint: null, action: TitleAction.filterFavorited),
    ]);
  }

  List<PopupMenuEntry<TitleAction>> _editMenu(BuildContext context) {
    return _items(const <_Entry?>[
      (label: '添加文件夹…', hint: 'Ctrl+O', action: TitleAction.addFolder),
      (label: '重新扫描全部', hint: 'Ctrl+R', action: TitleAction.rescan),
      (label: '重新洗牌推荐', hint: null, action: TitleAction.reshuffle),
      null,
      (label: '设置', hint: null, action: TitleAction.openSettings),
    ]);
  }

  List<PopupMenuEntry<TitleAction>> _windowMenu(BuildContext context) {
    return <PopupMenuEntry<TitleAction>>[
      ..._items(const <_Entry?>[
        (label: '全屏', hint: 'F11', action: TitleAction.toggleFullscreen),
        null,
        (label: '最小化', hint: null, action: TitleAction.minimize),
        (label: '最大化 / 还原', hint: null, action: TitleAction.toggleMaximize),
      ]),
      // 置顶是个开关，勾选状态得跟着真实窗口走
      _checkItem('始终置顶', _onTop, () => _toggleOnTop()),
    ];
  }

  List<PopupMenuEntry<TitleAction>> _helpMenu(BuildContext context) {
    return _items(const <_Entry?>[
      (label: '快捷键一览', hint: null, action: TitleAction.shortcuts),
      null,
      (label: '打开数据目录', hint: null, action: TitleAction.openDataDir),
      (label: '打开日志文件', hint: null, action: TitleAction.openLog),
      null,
      (label: 'GitHub 项目主页', hint: null, action: TitleAction.openRepo),
    ]);
  }

  List<PopupMenuEntry<TitleAction>> _aboutMenu(BuildContext context) {
    return _items(const <_Entry?>[
      (label: '版本信息…', hint: null, action: TitleAction.about),
      (label: '开源许可…', hint: null, action: TitleAction.licenses),
    ]);
  }

  List<PopupMenuEntry<TitleAction>> _items(List<_Entry?> defs) {
    return <PopupMenuEntry<TitleAction>>[
      for (final e in defs)
        if (e == null)
          const PopupMenuDivider(height: 9)
        else
          PopupMenuItem<TitleAction>(
            value: e.action,
            height: 32,
            child: _MenuRow(label: e.label, hint: e.hint),
          ),
    ];
  }

  /// 开关型菜单项（带勾）。它不返回 TitleAction，直接执行回调。
  PopupMenuItem<TitleAction> _checkItem(
    String label,
    bool checked,
    VoidCallback onTap,
  ) {
    return PopupMenuItem<TitleAction>(
      height: 32,
      onTap: onTap,
      child: _MenuRow(
        label: label,
        hint: null,
        trailing: checked
            ? const Icon(Icons.check, size: 14, color: AppTheme.primary)
            : null,
      ),
    );
  }
}

/// 菜单项定义。null 表示分隔线。
typedef _Entry = ({String label, String? hint, TitleAction action});

// ────────────────────── 小组件 ──────────────────────

class _MenuRow extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget? trailing;

  const _MenuRow({required this.label, this.hint, this.trailing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12.5,
            ),
          ),
          const Spacer(),
          if (hint != null)
            Text(
              hint!,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 悬停高亮。标题栏上一堆按钮都用它，省得每个都写一遍 MouseRegion。
class _HoverBox extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const _HoverBox({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<_HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<_HoverBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _hover ? AppTheme.titleHover : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final void Function(TitleAction)? onSelected;
  final List<PopupMenuEntry<TitleAction>> Function(BuildContext)? popupBuilder;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onSelected,
    this.popupBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 28,
      height: 26,
      child: Center(
        child: Icon(icon, size: 16, color: AppTheme.textSecondary),
      ),
    );

    final Widget body;
    if (popupBuilder == null) {
      body = _HoverBox(onTap: onTap, child: child);
    } else {
      body = PopupMenuButton<TitleAction>(
        tooltip: '',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 2),
        onSelected: onSelected,
        itemBuilder: popupBuilder!,
        child: _HoverBox(child: child),
      );
    }

    return Tooltip(message: tooltip, child: body);
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final List<PopupMenuEntry<TitleAction>> Function(BuildContext) buildItems;
  final void Function(TitleAction) onSelected;

  const _MenuButton({
    required this.label,
    required this.buildItems,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TitleAction>(
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 2),
      onSelected: onSelected,
      itemBuilder: buildItems,
      child: _HoverBox(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.border,
    );
  }
}

enum _Glyph { minimize, maximize, restore, close }

class _WindowButton extends StatefulWidget {
  final _Glyph glyph;
  final VoidCallback onTap;
  final bool danger;

  const _WindowButton({
    required this.glyph,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // 关闭按钮悬停时整块变红、图标转白；其余两个是浅灰底、图标提亮
    final bg = _hover
        ? (widget.danger ? AppTheme.closeHover : AppTheme.titleHover)
        : Colors.transparent;
    final fg = _hover && widget.danger
        ? Colors.white
        : (_hover ? AppTheme.textPrimary : AppTheme.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 46,
          height: AppConstants.titleBarHeight - 1,
          color: bg,
          child: Center(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CustomPaint(
                painter: _GlyphPainter(widget.glyph, fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 手画窗口按钮的图形
///
/// Material 的 remove / close 图标笔画粗细跟系统窗口按钮对不上，
/// 而且「还原」根本没有现成图标，干脆自己画 1px 的线。
class _GlyphPainter extends CustomPainter {
  final _Glyph glyph;
  final Color color;

  _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(Offset(cx - 5, cy), Offset(cx + 5, cy), p);
        break;

      case _Glyph.maximize:
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: 10, height: 10),
          p,
        );
        break;

      case _Glyph.restore:
        // 后面那个框只露出左上两条边，前面那个用底色盖住它的右下部分
        canvas.drawRect(Rect.fromLTWH(cx - 4.5, cy - 4.5, 8, 8), p);
        canvas.drawRect(
          Rect.fromLTWH(cx - 3.5, cy - 3.5, 8, 8),
          Paint()..color = AppTheme.titleBar,
        );
        canvas.drawRect(Rect.fromLTWH(cx - 3.5, cy - 3.5, 8, 8), p);
        break;

      case _Glyph.close:
        canvas.drawLine(Offset(cx - 5, cy - 5), Offset(cx + 5, cy + 5), p);
        canvas.drawLine(Offset(cx + 5, cy - 5), Offset(cx - 5, cy + 5), p);
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
