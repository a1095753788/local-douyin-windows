import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// 设置持久化（桌面新增）
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  HwdecMode _hwdecMode = HwdecMode.auto;
  CompletionBehavior _completionBehavior = CompletionBehavior.nextVideo;
  bool _pauseOnBlur = true;
  bool _pauseOnPageChange = true;
  double _defaultSpeed = 1.0;
  double _volume = 1.0;

  bool _danmakuEnabled = true;
  double _danmakuOpacity = 0.6;
  int _danmakuLanes = 5;
  double _danmakuFontSize = 13;

  String _ffmpegPath = '';
  String _thumbDir = '';

  bool _skipHidden = true;
  int _minFileSizeKb = 0;
  bool _deepScan = false;
  bool _watchEnabled = true;

  HwdecMode get hwdecMode => _hwdecMode;
  CompletionBehavior get completionBehavior => _completionBehavior;
  bool get pauseOnBlur => _pauseOnBlur;
  bool get pauseOnPageChange => _pauseOnPageChange;
  double get defaultSpeed => _defaultSpeed;
  double get volume => _volume;

  bool get danmakuEnabled => _danmakuEnabled;
  double get danmakuOpacity => _danmakuOpacity;
  int get danmakuLanes => _danmakuLanes;
  double get danmakuFontSize => _danmakuFontSize;

  String get ffmpegPath => _ffmpegPath;
  String get thumbDir => _thumbDir;

  bool get skipHidden => _skipHidden;
  int get minFileSizeKb => _minFileSizeKb;
  bool get deepScan => _deepScan;
  bool get watchEnabled => _watchEnabled;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;

    _hwdecMode = _enumOf(
      HwdecMode.values,
      p.getString('hwdec'),
      HwdecMode.auto,
    );
    _completionBehavior = _enumOf(
      CompletionBehavior.values,
      p.getString('completion'),
      CompletionBehavior.nextVideo,
    );
    _pauseOnBlur = p.getBool('pauseOnBlur') ?? true;
    _pauseOnPageChange = p.getBool('pauseOnPageChange') ?? true;
    _defaultSpeed = p.getDouble('defaultSpeed') ?? 1.0;
    _volume = p.getDouble('volume') ?? 1.0;

    _danmakuEnabled = p.getBool('danmakuEnabled') ?? true;
    _danmakuOpacity = p.getDouble('danmakuOpacity') ?? 0.6;
    _danmakuLanes = p.getInt('danmakuLanes') ?? 5;
    _danmakuFontSize = p.getDouble('danmakuFontSize') ?? 13;

    _ffmpegPath = p.getString('ffmpegPath') ?? '';
    _thumbDir = p.getString('thumbDir') ?? '';

    _skipHidden = p.getBool('skipHidden') ?? true;
    _minFileSizeKb = p.getInt('minFileSizeKb') ?? 0;
    _deepScan = p.getBool('deepScan') ?? false;
    _watchEnabled = p.getBool('watchEnabled') ?? true;

    notifyListeners();
  }

  T _enumOf<T>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final v in values) {
      if ((v as dynamic).name == name) return v;
    }
    return fallback;
  }

  Future<void> _set(String key, Future<bool> Function() write) async {
    await write();
    notifyListeners();
  }

  Future<void> setHwdecMode(HwdecMode v) => _set('hwdec', () async {
    _hwdecMode = v;
    return _prefs?.setString('hwdec', v.name) ?? Future.value(false);
  });

  Future<void> setCompletionBehavior(CompletionBehavior v) =>
      _set('completion', () async {
        _completionBehavior = v;
        return _prefs?.setString('completion', v.name) ?? Future.value(false);
      });

  Future<void> setPauseOnBlur(bool v) => _set('pauseOnBlur', () async {
    _pauseOnBlur = v;
    return _prefs?.setBool('pauseOnBlur', v) ?? Future.value(false);
  });

  Future<void> setPauseOnPageChange(bool v) =>
      _set('pauseOnPageChange', () async {
        _pauseOnPageChange = v;
        return _prefs?.setBool('pauseOnPageChange', v) ?? Future.value(false);
      });

  Future<void> setDefaultSpeed(double v) => _set('defaultSpeed', () async {
    _defaultSpeed = v;
    return _prefs?.setDouble('defaultSpeed', v) ?? Future.value(false);
  });

  Future<void> setVolume(double v) => _set('volume', () async {
    _volume = v;
    return _prefs?.setDouble('volume', v) ?? Future.value(false);
  });

  Future<void> setDanmakuEnabled(bool v) => _set('danmakuEnabled', () async {
    _danmakuEnabled = v;
    return _prefs?.setBool('danmakuEnabled', v) ?? Future.value(false);
  });

  Future<void> setDanmakuOpacity(double v) => _set('danmakuOpacity', () async {
    _danmakuOpacity = v;
    return _prefs?.setDouble('danmakuOpacity', v) ?? Future.value(false);
  });

  Future<void> setDanmakuLanes(int v) => _set('danmakuLanes', () async {
    _danmakuLanes = v;
    return _prefs?.setInt('danmakuLanes', v) ?? Future.value(false);
  });

  Future<void> setDanmakuFontSize(double v) =>
      _set('danmakuFontSize', () async {
        _danmakuFontSize = v;
        return _prefs?.setDouble('danmakuFontSize', v) ?? Future.value(false);
      });

  Future<void> setFfmpegPath(String v) => _set('ffmpegPath', () async {
    _ffmpegPath = v;
    return _prefs?.setString('ffmpegPath', v) ?? Future.value(false);
  });

  Future<void> setThumbDir(String v) => _set('thumbDir', () async {
    _thumbDir = v;
    return _prefs?.setString('thumbDir', v) ?? Future.value(false);
  });

  Future<void> setSkipHidden(bool v) => _set('skipHidden', () async {
    _skipHidden = v;
    return _prefs?.setBool('skipHidden', v) ?? Future.value(false);
  });

  Future<void> setMinFileSizeKb(int v) => _set('minFileSizeKb', () async {
    _minFileSizeKb = v;
    return _prefs?.setInt('minFileSizeKb', v) ?? Future.value(false);
  });

  Future<void> setDeepScan(bool v) => _set('deepScan', () async {
    _deepScan = v;
    return _prefs?.setBool('deepScan', v) ?? Future.value(false);
  });

  Future<void> setWatchEnabled(bool v) => _set('watchEnabled', () async {
    _watchEnabled = v;
    return _prefs?.setBool('watchEnabled', v) ?? Future.value(false);
  });
}
