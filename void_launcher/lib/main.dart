import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/void_theme.dart';
import 'features/launcher/home_screen.dart';
import 'features/lockscreen/lock_screen.dart';
import 'features/sphere/controller/sphere_controller.dart';
import 'services/haptic_util.dart';
import 'services/launcher_service.dart';

/// ═══════════════════════════════════════════════════════
/// VOID LAUNCHER — entry point.
///
/// Architecture at a glance:
///
///   VoidApp (MaterialApp, B/W theme)
///     └─ RootShell  ── SpherePhysicsTicker (ONE Ticker drives ALL springs)
///          ├─ LockScreen   → vertical drag sets rise target; lag spring
///          │                 animates the sphere with overshoot & settle
///          └─ HomeScreen   → horizontal flings navigate app pages; the
///                             sphere recoils elastically to center each
///                             time; drawer / search on gestures.
///
/// State: Riverpod. Physics: SpringSimulation (flutter/physics).
/// Rendering: CustomPainter glow (see GlowingSpherePainter).
/// Native bridge: MethodChannel 'void.launcher/bridge' (Kotlin LauncherBridge).
/// ═══════════════════════════════════════════════════════
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the device chrome out of the way — a launcher owns the screen.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Haptics availability check (silently no-ops without a vibrator).
  HapticUtil.init();

  runApp(
    ProviderScope(
      overrides: <Override>[
        // Swap in MockLauncherService here to preview without Android.
        launcherServiceProvider.overrideWithValue(PlatformLauncherService()),
      ],
      child: const VoidApp(),
    ),
  );
}

class VoidApp extends StatelessWidget {
  const VoidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Void Launcher',
      debugShowCheckedModeBanner: false,
      theme: VoidTheme.build(),
      home: const RootShell(),
    );
  }
}

/// Decides between lock screen and home, and hosts the global physics
/// ticker so every spring shares one clock.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  bool _locked = true;

  void _unlock() => setState(() => _locked = false);

  void _relock() {
    setState(() => _locked = true);
    // Sink the sphere again for the next arrival — it will re-rise with
    // its signature lag when the user swipes up once more.
    ref.read(sphereControllerProvider.notifier).resetToIdle();
  }

  @override
  Widget build(BuildContext context) {
    return SpherePhysicsTicker(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _locked
            ? LockScreen(key: const ValueKey<String>('lock'), onUnlock: _unlock)
            : HomeScreen(key: const ValueKey<String>('home'), onRelock: _relock),
      ),
    );
  }
}
