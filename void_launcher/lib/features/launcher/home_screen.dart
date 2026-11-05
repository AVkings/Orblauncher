import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/void_theme.dart';
import '../../models/installed_app.dart';
import '../../providers/app_providers.dart';
import '../app_drawer/app_drawer_sheet.dart';
import '../search/search_overlay.dart';
import '../sphere/controller/sphere_controller.dart';
import '../../services/haptic_util.dart';
import '../sphere/widgets/void_sphere.dart';
import 'widgets/app_page_grid.dart';
import 'widgets/page_indicator.dart';

/// ═══════════════════════════════════════════════════════
/// HOME SCREEN — app pages orbiting the sphere.
///
/// Gesture model (all fed into ONE physics clock via SphereController):
///   • Horizontal drag/fling on the lower area (the sphere zone) moves the
///     sphere with the finger; on release the page commits and the sphere
///     springs back to center while the grid cross-fades/slides.
///       – swipe LEFT  → NEXT page  → sphere slides RIGHT then recoils
///       – swipe RIGHT → PREV page  → sphere slides LEFT then recoils
///   • Swipe UP on the sphere opens the app drawer.
///   • Tap on the sphere opens search.
///   • Swipe DOWN from the top edge also opens search.
/// ═══════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onRelock});

  /// Pull-down-to-relock hook (returns to the lock screen).
  final VoidCallback onRelock;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Vertical drag bookkeeping for the "swipe up = drawer" gesture.
  double _vDragAccum = 0;

  @override
  void initState() {
    super.initState();
    // Register the page-commit hook once (controller → provider bridge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sphereControllerProvider.notifier).onCommitPage = _commitPage;
    });
  }

  @override
  void dispose() {
    ref.read(sphereControllerProvider.notifier).onCommitPage = null;
    super.dispose();
  }

  void _commitPage(bool forward) {
    final int pageCount = ref.read(pageCountProvider);
    final int current = ref.read(currentPageProvider);
    final int next =
        (forward ? current + 1 : current - 1).clamp(0, pageCount - 1);
    if (next != current) {
      ref.read(currentPageProvider.notifier).state = next;
      HapticUtil.selection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final TextTheme text = VoidTheme.textTheme(context);
    final int page = ref.watch(currentPageProvider);
    final int pageCount = ref.watch(pageCountProvider);
    final List<InstalledApp> apps = ref.watch(appsForPageProvider(page));
    final int columns = ref.watch(gridColumnsProvider);
    final bool loading = ref.watch(installedAppsProvider).isLoading;
    final SphereController controller =
        ref.read(sphereControllerProvider.notifier);

    return Scaffold(
      backgroundColor: VoidColors.background,
      body: Stack(
        children: <Widget>[
          // ── Top-edge pull-down handle → relock / search ─────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 48,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (DragEndDetails d) {
                final double v = d.primaryVelocity ?? 0;
                if (v > 500) {
                  SearchOverlay.open(context); // deliberate fast pull-down
                } else if (v > 250) {
                  widget.onRelock();
                }
              },
              child: Center(
                child: Container(
                  width: 34,
                  height: 3,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: VoidColors.foreground.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // ── App grid (current page) with spring-parallax ────────────
          Positioned.fill(
            child: _ParallaxGrid(
              // Grid drifts OPPOSITE the sphere during a drag → depth cue.
              builder: (double dragX) => Transform.translate(
                offset: Offset(dragX * -0.22, 0),
                child: Opacity(
                  opacity: (1 - dragX.abs() / screen.width * 0.9).clamp(0.1, 1.0),
                  child: loading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.2),
                          ),
                        )
                      : AppPageGrid(
                          apps: apps,
                          columns: columns,
                          onTapApp: (InstalledApp a) =>
                              ref.read(appLaunchControllerProvider).launch(a),
                          onLongPressApp: (_) => AppDrawerSheet.open(context),
                        ),
                ),
              ),
            ),
          ),
          // ── THE SPHERE layer + horizontal gesture surface ───────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // SWIPE NAVIGATION: feed live dx into the page spring.
              onHorizontalDragUpdate: (DragUpdateDetails d) =>
                  controller.dragPage(d.delta.dx),
              onHorizontalDragEnd: (DragEndDetails d) {
                final ({bool changed, bool forward}) r =
                    controller.flingPage(d.velocity.pixelsPerSecond.dx,
                        screen.width);
                if (r.changed) _commitPage(r.forward);
              },
              // SWIPE UP ON SPHERE ZONE → app drawer.
              onVerticalDragStart: (_) => _vDragAccum = 0,
              onVerticalDragUpdate: (DragUpdateDetails d) =>
                  _vDragAccum += d.delta.dy,
              onVerticalDragEnd: (_) {
                if (_vDragAccum < -80) {
                  HapticUtil.confirm();
                  AppDrawerSheet.open(context);
                } else if (_vDragAccum > 140) {
                  widget.onRelock();
                }
                _vDragAccum = 0;
              },
              child: const _SphereHitArea(),
            ),
          ),
          // ── Bottom chrome: page dots (above the sphere's rim) ───────
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: PageIndicator(count: pageCount, current: page),
              ),
            ),
          ),
          // Empty-state hint when no apps resolved yet.
          if (!loading && apps.isEmpty && page == 0)
            Positioned(
              top: screen.height * 0.3,
              left: 0,
              right: 0,
              child: Center(
                child: Text('the void is empty…', style: text.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reads the sphere's live page-drag value so the grid can parallax against
/// it without rebuilding the whole screen every frame.
class _ParallaxGrid extends ConsumerWidget {
  const _ParallaxGrid({required this.builder});
  final Widget Function(double dragX) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only pageDragX (cheap selector-like rebuild).
    final double dragX =
        ref.watch(sphereControllerProvider.select((s) => s.pageX));
    return builder(dragX);
  }
}

/// Renders the sphere itself + swallows taps for quick-search.
class _SphereHitArea extends ConsumerWidget {
  const _SphereHitArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SphereState s = ref.watch(sphereControllerProvider);
    final Size screen = MediaQuery.of(context).size;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => ref.read(sphereControllerProvider.notifier).setPressed(true),
      onTapCancel: () =>
          ref.read(sphereControllerProvider.notifier).setPressed(false),
      onTap: () {
        ref.read(sphereControllerProvider.notifier).setPressed(false);
        SearchOverlay.open(context);
      },
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: VoidSphere(
            size: screen.width * 1.6,
            rise: s.lag.clamp(0.0, 1.3),
            pageX: s.pageX,
            glow: s.glowPulse,
            pressScale: s.pressScale,
            tilt: s.tilt,
          ),
        ),
      ),
    );
  }
}

