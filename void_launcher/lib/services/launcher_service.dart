import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/installed_app.dart';

/// Thin wrapper over the Kotlin `LauncherBridge` (MethodChannel).
///
/// Why a platform channel instead of `device_apps`?
/// Android 11+ (API 30) enforces package-visibility rules that break most
/// community packages when running as a HOME role holder. The bundled Kotlin
/// service declares `<queries>` + RoleManager, so enumeration and launching
/// are guaranteed to work on modern Android. A graceful [MockLauncherService]
/// keeps the Dart layer fully testable.
abstract class LauncherService {
  Future<List<InstalledApp>> getInstalledApps({bool withIcons = true});
  Future<void> launchApp(String packageName);
  Future<bool> isDefaultLauncher();
  Future<void> requestHomeRole();
  Future<void> openDefaultAppsSettings();
}

class PlatformLauncherService implements LauncherService {
  PlatformLauncherService() {
    _channel.setMethodCallHandler(_onNativeEvent);
  }

  static const MethodChannel _channel =
      MethodChannel('void.launcher/bridge');

  /// Native → Flutter events (e.g. "the user reinstalled apps").
  final StreamController<List<InstalledApp>> _refreshStream =
      StreamController<List<InstalledApp>>.broadcast();

  Stream<List<InstalledApp>> get onAppsChanged => _refreshStream.stream;

  Future<dynamic> _onNativeEvent(MethodCall call) async {
    if (call.method == 'appsChanged') {
      _refreshStream.add(await getInstalledApps(withIcons: false));
    }
  }

  @override
  Future<List<InstalledApp>> getInstalledApps(
      {bool withIcons = true}) async {
    try {
      final List<Object?>? raw = await _channel
          .invokeMethod<List<Object?>>('getApps', <String, Object>{
        'icons': withIcons,
      });
      if (raw == null) return <InstalledApp>[];
      final List<InstalledApp> apps = raw
          .cast<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> m) => InstalledApp(
                packageName: m['packageName']! as String,
                appName: m['appName']! as String,
                isLaunchable: (m['isLaunchable'] as bool?) ?? true,
                iconBytes: m['icon'] as Uint8List?,
              ))
          .toList();
      apps.sort((InstalledApp a, InstalledApp b) =>
          a.sortKey.compareTo(b.sortKey));
      return apps;
    } on PlatformException catch (e, s) {
      debugPrint('getApps failed: ${e.code} ${e.message}');
      if (kDebugMode) debugPrintStack(stackTrace: s);
      return <InstalledApp>[];
    }
  }

  @override
  Future<void> launchApp(String packageName) {
    return _channel.invokeMethod<void>('launchApp',
        <String, Object>{'packageName': packageName});
  }

  @override
  Future<bool> isDefaultLauncher() async {
    final bool? v =
        await _channel.invokeMethod<bool>('isDefaultLauncher');
    return v ?? false;
  }

  @override
  Future<void> requestHomeRole() {
    // Opens the system "choose your default home app" sheet (API 29+),
    // or Settings → Default apps on older devices (handled natively).
    return _channel.invokeMethod<void>('requestHomeRole');
  }

  @override
  Future<void> openDefaultAppsSettings() {
    return _channel.invokeMethod<void>('openDefaultAppsSettings');
  }
}

/// Deterministic stand-in used by widget tests and non-Android runs.
class MockLauncherService implements LauncherService {
  MockLauncherService({int appCount = 42})
      : _apps = List<InstalledApp>.generate(
          appCount,
          (int i) => InstalledApp(
            packageName: 'com.mock.app$i',
            appName: 'App ${String.fromCharCode(65 + (i % 26))}$i',
            isLaunchable: true,
          ),
        ).toList()..sort((InstalledApp a, InstalledApp b) =>
            math.Random(a.id).nextInt(1).compareTo(math.Random(b.id).nextInt(1)));

  final List<InstalledApp> _apps;
  final List<String> launched = <String>[];

  @override
  Future<List<InstalledApp>> getInstalledApps(
          {bool withIcons = true}) async =>
      _apps;

  @override
  Future<void> launchApp(String packageName) async =>
      launched.add(packageName);

  @override
  Future<bool> isDefaultLauncher() async => false;

  @override
  Future<void> requestHomeRole() async {}

  @override
  Future<void> openDefaultAppsSettings() async {}
}
