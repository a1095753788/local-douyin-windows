import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_log.dart';
import '../core/constants.dart';
import '../data/models/video_item.dart';
import '../data/repositories/video_repository.dart';

/// 播放器
///
/// 与手机版的区别：
///   - 单 Player 复用，切换不重建（手机版每次 dispose+new，黑屏 200~400ms）
///   - 断点续播真正实现（手机版 watchProgress 只写不读，且从未写入）
///   - playCount 有阈值：看满 3 秒或 10% 才 +1（手机版一可见就 +1）
///   - 播完默认自动下一条（手机版是 PlaylistMode.loop，永远重播同一条）
///   - 防息屏只在播放时（手机版一开 App 就永久不休眠）
class PlayerProvider extends ChangeNotifier {
  final VideoRepository _repo = VideoRepository();

  Player? _player;
  VideoController? _controller;
  VideoItem? _current;

  bool _ready = false;
  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  double _volume = 1.0;
  bool _muted = false;
  String? _error;

  /// 非致命提示：视频能播，只是某条轨（通常是音轨）有问题
  String? _notice;

  /// 代际号。每 open 一次 +1，用来丢掉上一条视频迟到的错误事件
  int _openSeq = 0;

  /// 错误判定延迟定时器（先等一等，看视频到底起没起来）
  Timer? _errorTimer;

  String _hwdecActual = '';
  String _container = '';
  String _codec = '';

  HwdecMode _mode = HwdecMode.auto;
  CompletionBehavior _completion = CompletionBehavior.nextVideo;

  // 播放计数
  int _sessionPlayedMs = 0;
  DateTime? _playStart;
  bool _counted = false;

  // 进度写回
  Timer? _saveTimer;
  int _lastSavedMs = 0;

  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];

  /// 播完自动下一条时回调（由 UI 层注入）
  VoidCallback? onAutoNext;

  /// 需要刷新视频状态时回调（点赞/计数变化）
  void Function(String videoId)? onVideoChanged;

  Player? get player => _player;
  VideoController? get controller => _controller;
  VideoItem? get current => _current;
  bool get ready => _ready;
  bool get playing => _playing;
  bool get buffering => _buffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;
  double get volume => _volume;
  bool get muted => _muted;
  String? get error => _error;
  String? get notice => _notice;
  String get hwdecActual => _hwdecActual;
  String get container => _container;
  String get codec => _codec;

  double get progress {
    final d = _duration.inMilliseconds;
    if (d <= 0) return 0;
    return (_position.inMilliseconds / d).clamp(0.0, 1.0);
  }

  bool get hasVideo => _current != null;

  Future<void> init({
    HwdecMode mode = HwdecMode.auto,
    CompletionBehavior completion = CompletionBehavior.nextVideo,
    double speed = 1.0,
    double volume = 1.0,
  }) async {
    _mode = mode;
    _completion = completion;
    _speed = speed;
    _volume = volume;
    await _createPlayer();
  }

  Future<void> _createPlayer() async {
    await _disposePlayer();

    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 64 * 1024 * 1024),
    );
    _controller = VideoController(
      _player!,
      configuration: VideoControllerConfiguration(hwdec: _mode.mpvValue),
    );

    _bind();
    _ready = true;
    notifyListeners();
  }

  void _bind() {
    final p = _player;
    if (p == null) return;

    _subs.add(
      p.stream.position.listen((v) {
        _position = v;
        notifyListeners();
      }),
    );
    _subs.add(
      p.stream.duration.listen((v) {
        _duration = v;
        notifyListeners();
      }),
    );
    _subs.add(
      p.stream.playing.listen((v) {
        _onPlayingChanged(v);
      }),
    );
    _subs.add(
      p.stream.buffering.listen((v) {
        _buffering = v;
        notifyListeners();
      }),
    );
    _subs.add(
      p.stream.completed.listen((v) {
        if (v) _onCompleted();
      }),
    );
    _subs.add(
      p.stream.error.listen((e) {
        _onPlayerError(e);
      }),
    );
  }

  /// 收到 mpv 的错误事件
  ///
  /// 关键认知：media_kit 的 `stream.error` **不是**「视频打不开」的意思。
  /// 它只是把 mpv 日志里 level=error 的消息原样转出来，来源包括：
  ///   - `ad`  音频解码器 → "Error decoding audio."（画面照样正常播）
  ///   - `vd`  视频解码器
  ///   - `cplayer` / `stream` / `ffmpeg` 各种杂音
  ///
  /// 所以不能一收到就盖住整个画面。判定办法是**等 1.5 秒看视频有没有真的起来**：
  ///   - 进度在走，或已经读出了时长 → 文件能打开，这只是一条轨的小毛病 → 降级为提示
  ///   - 什么都没有 → 真打不开 → 才算致命错误
  void _onPlayerError(String raw) {
    final seq = _openSeq;
    final posAtError = _position;

    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(milliseconds: 1500), () {
      // 已经切到下一条了，这是上一条迟到的错误，丢掉
      if (seq != _openSeq) return;

      final canPlay = canPlayDespiteError(
        posAtError: posAtError,
        posNow: _position,
        duration: _duration,
      );

      AppLog.w(
        'player',
        'mpv 错误 seq=$seq pos=${_position.inMilliseconds} '
            'duration=${_duration.inMilliseconds} => '
            '${canPlay ? "可播，忽略" : "不可播"} : $raw',
      );

      if (canPlay) {
        _error = null;
        // 只保留有意义的提示，别让后面一条无关杂音把它覆盖成 null
        final n = noticeFor(raw);
        if (n != null) _notice = n;
      } else {
        _error = friendlyError(raw);
        _notice = null;
      }
      notifyListeners();
    });
  }

  /// 收到错误 1.5 秒后，判断「这条视频到底能不能看」
  ///
  /// 判据故意**不用** playing：`open(play: true)` 时 mpv 可能立刻把 playing
  /// 置成 true，哪怕文件根本打不开。只认两条硬证据：
  ///   1. 进度真的往前走了
  ///   2. 已经读出了时长（说明容器/文件头是好的）
  @visibleForTesting
  static bool canPlayDespiteError({
    required Duration posAtError,
    required Duration posNow,
    required Duration duration,
  }) {
    final advanced = posNow > posAtError + const Duration(milliseconds: 50);
    final opened = duration > Duration.zero;
    return advanced || opened;
  }

  /// 能播的情况下，只把「音轨坏了」这种用户会感知到的说一句，其余杂音吞掉
  @visibleForTesting
  static String? noticeFor(String raw) {
    final s = raw.toLowerCase();
    // mpv 的 ad（音频解码器）报错原文一般是
    //   "Error decoding audio."
    //   "Could not open codec."
    // 只认 audio，宁可少提示也别误报
    if (s.contains('audio')) {
      return '这条视频的音轨解不开，已静音播放';
    }
    return null;
  }

  /// 真打不开时，把 mpv 的英文原文翻成人话
  @visibleForTesting
  static String friendlyError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('audio')) return '音频轨解码失败：$raw';
    if (s.contains('video')) return '视频轨解码失败：$raw';
    if (s.contains('no such file') || s.contains('not found')) {
      return '文件找不到了，可能被移动或删除';
    }
    if (s.contains('failed to open') || s.contains('cannot open')) {
      return '打不开这个文件：$raw';
    }
    return raw;
  }

  void _onPlayingChanged(bool playing) {
    if (_playing == playing) return;

    if (playing) {
      _playStart = DateTime.now();
    } else {
      if (_playStart != null) {
        _sessionPlayedMs += DateTime.now()
            .difference(_playStart!)
            .inMilliseconds;
        _playStart = null;
      }
    }
    _playing = playing;
    _checkPlayCount();
    notifyListeners();
  }

  /// 播放计数：看满 3 秒或进度 10% 才 +1，且每条只算一次
  void _checkPlayCount() {
    if (_counted) return;
    final v = _current;
    if (v == null) return;

    final live = _playStart == null
        ? 0
        : DateTime.now().difference(_playStart!).inMilliseconds;
    final playedMs = _sessionPlayedMs + live;

    if (playedMs >= AppConstants.playCountMinMs ||
        progress >= AppConstants.playCountMinProgress) {
      _counted = true;
      unawaited(
        _repo.incrementPlayCount(v.id).then((_) {
          onVideoChanged?.call(v.id);
        }),
      );
    }
  }

  Future<void> _onCompleted() async {
    _checkPlayCount();
    await _saveProgressNow();
    switch (_completion) {
      case CompletionBehavior.loopSingle:
        await _player?.seek(Duration.zero);
        await _player?.play();
        break;
      case CompletionBehavior.pause:
        await _player?.pause();
        break;
      case CompletionBehavior.nextVideo:
        onAutoNext?.call();
        break;
    }
  }

  /// 打开一个视频
  ///
  /// 会先保存上一条的进度，再切换，最后按条件续播。
  Future<void> open(VideoItem v, {bool autoPlay = true}) async {
    if (_player == null) await _createPlayer();

    // 1) 保存上一条
    await _saveProgressNow();

    // 2) 重置状态
    // 代际号 +1：上一条视频迟到的错误事件会因为 seq 不匹配被丢掉，
    // 否则会出现「上一条音轨报错，新的一条明明好好的却顶着红色遮罩」
    _openSeq++;
    _errorTimer?.cancel();
    _current = v;
    _error = null;
    _notice = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _sessionPlayedMs = 0;
    _playStart = null;
    _counted = false;
    _lastSavedMs = 0;
    _hwdecActual = '';
    _container = '';
    _codec = '';
    notifyListeners();

    try {
      await _player!.open(Media(v.playPath), play: autoPlay);
      await _player!.setRate(_speed);
      await _player!.setVolume(_muted ? 0 : _volume * 100);

      // 3) 断点续播
      await _maybeResume(v);

      // 4) 读属性（容器/编码/实际解码器）
      unawaited(_readProps());

      // 5) 启动进度写回定时器
      _startSaveTimer();
    } catch (e) {
      _error = friendlyError(e.toString());
      _notice = null;
      notifyListeners();
    }
  }

  Future<void> _maybeResume(VideoItem v) async {
    // 等 duration 出来
    for (var i = 0; i < 20 && _duration.inMilliseconds <= 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final pos = v.resumePosition;
    final dur = _duration.inMilliseconds;
    if (pos <= AppConstants.resumeMinMs) return;
    if (dur > 0 && pos >= dur - AppConstants.resumeTailMs) return;
    try {
      await _player?.seek(Duration(milliseconds: pos));
    } catch (_) {}
  }

  Future<void> _readProps() async {
    final np = _player?.platform;
    if (np is! NativePlayer) return;

    Future<String> get(String key) async {
      try {
        final v = await np.getProperty(key);
        return v.isEmpty ? '-' : v;
      } catch (_) {
        return '-';
      }
    }

    final hwdec = await get('hwdec-current');
    final fmt = await get('file-format');
    final codec = await get('video-codec');

    _hwdecActual = hwdec;
    _container = fmt;
    _codec = codec;

    // 顺手把元数据补进库（首次播放时能补上扫描没拿到的时长）
    final v = _current;
    if (v != null && (v.duration == null || v.duration! <= 0)) {
      final w = int.tryParse(await get('width')) ?? 0;
      final h = int.tryParse(await get('height')) ?? 0;
      if (_duration.inMilliseconds > 0) {
        unawaited(
          _repo.updateMetadata(
            v.id,
            duration: _duration.inMilliseconds,
            width: w,
            height: h,
          ),
        );
      }
    }

    notifyListeners();
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.progressSaveIntervalMs),
      (_) {
        // 播放计数不能只挂在 playing 的翻转上：
        // 一条视频从头播到尾可能一次都不翻转（开播即 true，播完直接切下一条），
        // 那样 playCount 永远是 0。所以每 2 秒兜一次。
        _checkPlayCount();
        _saveProgressNow();
      },
    );
  }

  /// 把当前进度写回数据库
  Future<void> _saveProgressNow() async {
    final v = _current;
    if (v == null) return;
    final ms = _position.inMilliseconds;
    if (ms <= 0) return;
    // 位置没变就不写，减少 IO
    if ((ms - _lastSavedMs).abs() < 800) return;
    _lastSavedMs = ms;

    final live = _playStart == null
        ? 0
        : DateTime.now().difference(_playStart!).inMilliseconds;
    final addMs = _sessionPlayedMs + live;
    _sessionPlayedMs = addMs;
    if (_playStart != null) _playStart = DateTime.now();

    try {
      await _repo.saveProgress(
        v.id,
        resumePosition: ms,
        progress: progress,
        addWatchMs: addMs,
      );
    } catch (_) {}
  }

  Future<void> playPause() async {
    await _player?.playOrPause();
  }

  Future<void> play() async {
    await _player?.play();
  }

  Future<void> pause() async {
    await _player?.pause();
  }

  Future<void> setSpeed(double s) async {
    _speed = s.clamp(AppConstants.speedMin, AppConstants.speedMax);
    await _player?.setRate(_speed);
    notifyListeners();
  }

  Future<void> nudgeSpeed(double delta) => setSpeed(_speed + delta);

  Future<void> seek(Duration d) async {
    await _player?.seek(d);
  }

  Future<void> seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final max = _duration;
    var t = target;
    if (t < Duration.zero) t = Duration.zero;
    if (max > Duration.zero && t > max) t = max;
    await seek(t);
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (!_muted) await _player?.setVolume(_volume * 100);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    await _player?.setVolume(_muted ? 0 : _volume * 100);
    notifyListeners();
  }

  /// 切换解码方式需要重建 Player（hwdec 只能在创建时设置）
  Future<void> setHwdecMode(HwdecMode mode) async {
    if (_mode == mode) return;
    final v = _current;
    _mode = mode;
    await _createPlayer();
    if (v != null) {
      await open(v);
    }
  }

  void setCompletionBehavior(CompletionBehavior c) {
    _completion = c;
  }

  /// 离开当前视频（切页/失焦/关闭时调用）
  Future<void> leave() async {
    await _saveProgressNow();
    _saveTimer?.cancel();
    _saveTimer = null;
    await _player?.pause();
  }

  Future<void> stop() async {
    await _saveProgressNow();
    _saveTimer?.cancel();
    _saveTimer = null;
    _errorTimer?.cancel();
    _openSeq++;
    _error = null;
    _notice = null;
    _current = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    await _player?.stop();
    notifyListeners();
  }

  Future<void> _disposePlayer() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _controller = null;
    _ready = false;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _errorTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    super.dispose();
  }
}
