import 'package:path/path.dart' as p;

class FolderItem {
  final String id;
  final String path;
  final String name;
  final int videoCount;
  final int addedAt;
  final int lastScannedAt;
  final bool autoScan;

  /// 路径是否还存在。不存在时界面灰显，不崩溃
  final bool available;

  const FolderItem({
    required this.id,
    required this.path,
    required this.name,
    this.videoCount = 0,
    this.addedAt = 0,
    this.lastScannedAt = 0,
    this.autoScan = true,
    this.available = true,
  });

  String get displayName {
    final base = p.basename(path);
    return base.isEmpty ? name : base;
  }

  FolderItem copyWith({
    String? id,
    String? path,
    String? name,
    int? videoCount,
    int? addedAt,
    int? lastScannedAt,
    bool? autoScan,
    bool? available,
  }) {
    return FolderItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      videoCount: videoCount ?? this.videoCount,
      addedAt: addedAt ?? this.addedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      autoScan: autoScan ?? this.autoScan,
      available: available ?? this.available,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'path': path,
    'name': name,
    'videoCount': videoCount,
    'addedAt': addedAt,
    'lastScannedAt': lastScannedAt,
    'autoScan': autoScan ? 1 : 0,
    'available': available ? 1 : 0,
  };

  factory FolderItem.fromMap(Map<String, Object?> m) {
    return FolderItem(
      id: m['id'] as String,
      path: (m['path'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      videoCount: (m['videoCount'] as int?) ?? 0,
      addedAt: (m['addedAt'] as int?) ?? 0,
      lastScannedAt: (m['lastScannedAt'] as int?) ?? 0,
      autoScan: (m['autoScan'] as int?) != 0,
      available: (m['available'] as int?) != 0,
    );
  }
}
