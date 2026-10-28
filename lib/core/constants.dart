/// 全局常量
///
/// 格式白名单扩到 39 种（手机版只有 12 种）。
/// libmpv 内部是完整 FFmpeg，这些容器的解码器全都有，不需要转码。
class AppConstants {
  AppConstants._();

  static const String appName = '本地抖音';
  static const String appNameEn = 'LocalDouyin';
  static const String dbName = 'local_douyin.db';
  static const int dbVersion = 6;

  // ── 视频格式（39 种）──
  // 比手机版新增：rm/rmvb、m2ts/mts、vob、f4v、ogv/ogm、divx、
  // wtv、h264/h265/hevc、dv、mj2、amv、ivf、y4m、qt、swf、asf、mxf、nut 等
  static const List<String> supportedVideoExtensions = <String>[
    'mp4', 'm4v', 'mov', 'qt', 'mkv', 'webm', 'avi', 'divx', //
    'wmv', 'asf', 'flv', 'f4v', 'swf', 'ts', 'm2ts', 'mts', //
    'mpg', 'mpeg', 'mpe', 'm1v', 'm2v', 'vob', '3gp', '3g2', //
    'ogv', 'ogm', 'rm', 'rmvb', 'mxf', 'wtv', 'nut', 'dv', //
    'mj2', 'amv', 'ivf', 'h264', 'h265', 'hevc', 'y4m', //
  ];

  static bool isSupportedExtension(String ext) =>
      supportedVideoExtensions.contains(ext.toLowerCase());

  // ── 推荐算法参数（与手机版一致，只修 bug 不调参）──
  static const double exploreEpsilon = 0.15; // ε-greedy 探索率
  static const int maxConsecutivePerFolder = 2; // 同文件夹连续上限
  static const int minPoolSize = 20; // 低于此值时清空会话记忆，避免池枯竭
  static const int recentlyShownLimit = 30; // 会话内短期去重队列长度
  static const double exploitRatio = 0.7; // 前 70% 为利用池

  // ── 播放计数（修正手机版「一可见就 +1」）──
  static const int playCountMinMs = 3000; // 累计播放 3 秒
  static const double playCountMinProgress = 0.10; // 或进度 10%

  // ── 断点续播 ──
  static const int resumeMinMs = 5000; // 不足 5 秒不续播
  static const int resumeTailMs = 3000; // 距结尾不足 3 秒不续播
  static const int progressSaveIntervalMs = 2000; // 进度写库节流

  // ── 缩略图 ──
  static const int thumbWidth = 480;
  static const int thumbQuality = 4; // ffmpeg -q:v
  static const double thumbPositionRatio = 0.1; // 取时长 10% 处
  static const int thumbPositionMaxMs = 3000;
  static const int thumbPositionMinMs = 500;

  // ── 倍速 ──
  static const List<double> speedPresets = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];
  static const double speedMin = 0.5;
  static const double speedMax = 2.0;
  static const double speedStep = 0.1;

  // ── 扫描 ──
  static const int scanProgressEvery = 200; // 每扫多少个文件回传一次进度
  static const int scanBatchSize = 50; // 每多少条一个事务
  static const int watchDebounceMs = 5000; // 文件监视防抖

  // ── 布局 ──
  static const double windowMinWidth = 900;
  static const double windowMinHeight = 600;
  static const double windowDefaultWidth = 1280;
  static const double windowDefaultHeight = 800;
  static const double breakpointThreeCol = 1100;
  static const double breakpointTwoCol = 900;
  static const double sidebarWidth = 200;
  static const double sidebarCollapsedWidth = 64;
  static const double infoPanelWidth = 320;
}

/// 播放器的三种解码策略
enum HwdecMode {
  auto('自动', 'auto-safe'),
  software('软解', 'no'),
  hardware('硬解', 'd3d11va');

  const HwdecMode(this.label, this.mpvValue);
  final String label;
  final String mpvValue;
}

/// 播完一条之后的行为
enum CompletionBehavior {
  nextVideo('自动下一条'),
  loopSingle('单条循环'),
  pause('播完暂停');

  const CompletionBehavior(this.label);
  final String label;
}
