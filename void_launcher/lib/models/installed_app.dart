import 'dart:typed_data';

/// A single installed application, as delivered by the Kotlin side of the
/// platform channel. Icons arrive as raw PNG bytes and are decoded lazily.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.appName,
    required this.isLaunchable,
    this.iconBytes,
  });

  final String packageName;
  final String appName;
  final bool isLaunchable;
  final Uint8List? iconBytes;

  /// Stable id used for keys & favorites ordering.
  String get id => packageName;

  /// Alphabetical sort key (case-insensitive).
  String get sortKey => appName.toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is InstalledApp && other.packageName == packageName;

  @override
  int get hashCode => packageName.hashCode;
}
