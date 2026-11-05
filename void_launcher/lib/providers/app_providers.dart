import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/installed_app.dart';
import '../services/haptic_util.dart';
import '../services/launcher_service.dart';

/// Overridden in main() — [PlatformLauncherService] on device,
/// [MockLauncherService] in tests.
final Provider<LauncherService> launcherServiceProvider =
    Provider<LauncherService>((Ref ref) => PlatformLauncherService());

/// Async list of launchable apps, alphabetically sorted by the service.
final FutureProvider<List<InstalledApp>> installedAppsProvider =
    FutureProvider<List<InstalledApp>>((Ref ref) async {
  final LauncherService svc = ref.watch(launcherServiceProvider);
  return svc.getInstalledApps(withIcons: true);
});

/// How many app columns the home pages use (phone ⇒ 4).
final Provider<int> gridColumnsProvider =
    Provider<int>((Ref ref) => 4);

/// Items per page = columns × rows.
final Provider<int> itemsPerPageProvider =
    Provider<int>((Ref ref) => ref.watch(gridColumnsProvider) * 3);

/// Current home page index (0-based). The UI clamps against pageCount.
final StateProvider<int> currentPageProvider =
    StateProvider<int>((Ref ref) => 0);

/// Derived total number of pages for pagination dots & clamping.
final Provider<int> pageCountProvider = Provider<int>((Ref ref) {
  final List<InstalledApp>? apps =
      ref.watch(installedAppsProvider).valueOrNull;
  final int per = ref.watch(itemsPerPageProvider);
  if (apps == null || apps.isEmpty) return 1;
  return (apps.length / per).ceil();
});

/// Slice of apps shown on a given home page.
final ProviderFamily<List<InstalledApp>, int> appsForPageProvider =
    Provider.autoDispose
        .family<List<InstalledApp>, int>((Ref ref, int page) {
  final List<InstalledApp> all =
      ref.watch(installedAppsProvider).valueOrNull ?? <InstalledApp>[];
  final int per = ref.watch(itemsPerPageProvider);
  final int start = page * per;
  if (start >= all.length) return <InstalledApp>[];
  return all.sublist(start, (start + per).clamp(0, all.length));
});

/// Case-insensitive search over app names (used by the search overlay).
final FamilyProvider<List<InstalledApp>, String> searchResultsProvider =
    Provider.family<List<InstalledApp>, String>((Ref ref, String query) {
  final List<InstalledApp> all =
      ref.watch(installedAppsProvider).valueOrNull ?? <InstalledApp>[];
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where((InstalledApp a) => a.sortKey.contains(q))
      .toList(growable: false);
});

/// Launch an app with haptic confirmation; errors are swallowed quietly
/// (a launcher must never crash on a broken third-party intent).
class AppLaunchController {
  AppLaunchController(this._ref);
  final Ref _ref;

  Future<void> launch(InstalledApp app) async {
    HapticUtil.confirm();
    try {
      await _ref.read(launcherServiceProvider).launchApp(app.packageName);
    } catch (e) {
      debugPrint('launch failed for ${app.packageName}: $e');
    }
  }
}

final Provider<AppLaunchController> appLaunchControllerProvider =
    Provider<AppLaunchController>((Ref ref) => AppLaunchController(ref));

/// HOME-role status surfaced to the onboarding chip/banner.
final FutureProvider<bool> isDefaultLauncherProvider =
    FutureProvider<bool>((Ref ref) async {
  try {
    return ref.watch(launcherServiceProvider).isDefaultLauncher();
  } catch (_) {
    return false;
  }
});
