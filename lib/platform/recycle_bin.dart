import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// `SHFILEOPSTRUCTW` 的内存布局（x64）
///
/// ```
/// HWND     hwnd;          // 8
/// UINT     wFunc;         // 4 (+4 pad)
/// PCZZWSTR pFrom;         // 8
/// PCZZWSTR pTo;           // 8
/// WORD     fFlags;        // 2 (+2 pad)
/// BOOL     fAnyOperationsAborted; // 4
/// LPVOID   hNameMappings; // 8
/// PCWSTR   lpszProgressTitle; // 8
/// ```
final class _ShFileOpStruct extends Struct {
  external Pointer<Void> hwnd;
  @Uint32()
  external int wFunc;
  external Pointer<Uint16> pFrom;
  external Pointer<Uint16> pTo;
  @Uint16()
  external int fFlags;
  @Int32()
  external int fAnyOperationsAborted;
  external Pointer<Void> hNameMappings;
  external Pointer<Uint16> lpszProgressTitle;
}

typedef _ShFileOpNative = Int32 Function(Pointer<_ShFileOpStruct>);
typedef _ShFileOpDart = int Function(Pointer<_ShFileOpStruct>);

/// 把文件移到回收站（可撤销），或永久删除
///
/// 手机版只有「永久 delete」，桌面上一次可能删几百个文件，
/// 误删不可逆的代价太高，所以默认走回收站。
///
/// 这里不用 package:win32 的生成绑定——它的版本间签名改过几次，
/// 直接 dlsym 拿 shell32!SHFileOperationW 更稳，也少一个依赖。
class RecycleBin {
  RecycleBin._();

  static const int _foDelete = 3;

  static const int _fofSilent = 0x0004;
  static const int _fofNoConfirmation = 0x0010;
  static const int _fofAllowUndo = 0x0040;
  static const int _fofNoErrorUi = 0x0400;

  static _ShFileOpDart? _fn;

  static _ShFileOpDart? _resolve() {
    if (_fn != null) return _fn;
    if (!Platform.isWindows) return null;
    try {
      final lib = DynamicLibrary.open('shell32.dll');
      _fn = lib.lookupFunction<_ShFileOpNative, _ShFileOpDart>(
        'SHFileOperationW',
      );
      return _fn;
    } catch (_) {
      return null;
    }
  }

  /// 移到回收站。返回 (成功数, 失败路径列表)
  static ({int ok, List<String> failed}) moveToTrash(List<String> paths) {
    final existing = paths.where((e) => File(e).existsSync()).toList();
    if (existing.isEmpty) return (ok: 0, failed: <String>[]);

    final fn = _resolve();
    if (fn == null) {
      // 非 Windows 或 shell32 取不到：退化为永久删除
      return deletePermanently(existing);
    }

    Pointer<Uint16>? buffer;
    Pointer<_ShFileOpStruct>? op;
    try {
      // pFrom 需要「双 null 结尾」：每个路径后一个 \0，最后再来一个 \0
      var units = 1;
      for (final path in existing) {
        units += path.length + 1;
      }

      buffer = calloc<Uint16>(units);
      var idx = 0;
      for (final path in existing) {
        for (final unit in path.codeUnits) {
          buffer[idx++] = unit;
        }
        buffer[idx++] = 0;
      }
      buffer[idx] = 0;

      op = calloc<_ShFileOpStruct>();
      op.ref.wFunc = _foDelete;
      op.ref.pFrom = buffer;
      op.ref.pTo = nullptr;
      op.ref.fFlags =
          _fofAllowUndo | _fofSilent | _fofNoConfirmation | _fofNoErrorUi;
      op.ref.hNameMappings = nullptr;
      op.ref.lpszProgressTitle = nullptr;

      final result = fn(op);

      if (result == 0) {
        return (ok: existing.length, failed: <String>[]);
      }
      // 返回非 0 时逐个复查：文件已经不在原位 → 认为成功
      final failed = existing.where((e) => File(e).existsSync()).toList();
      return (ok: existing.length - failed.length, failed: failed);
    } catch (_) {
      return (ok: 0, failed: existing);
    } finally {
      if (op != null) calloc.free(op);
      if (buffer != null) calloc.free(buffer);
    }
  }

  /// 永久删除（不进回收站）
  static ({int ok, List<String> failed}) deletePermanently(List<String> paths) {
    var ok = 0;
    final failed = <String>[];
    for (final path in paths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
        }
        ok++;
      } catch (_) {
        failed.add(path);
      }
    }
    return (ok: ok, failed: failed);
  }

  /// 在资源管理器中显示并选中
  static Future<bool> revealInExplorer(String path) async {
    try {
      await Process.run('explorer.exe', <String>['/select,', path]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 打开文件所在目录
  static Future<bool> openContainingFolder(String path) async {
    try {
      await Process.run('explorer.exe', <String>[File(path).parent.path]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 用系统默认播放器打开
  static Future<bool> openWithSystemPlayer(String path) async {
    try {
      await Process.run('rundll32.exe', <String>[
        'url.dll,FileProtocolHandler',
        path,
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool exists(String path) => File(path).existsSync();
}
