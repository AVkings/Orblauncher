import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/void_theme.dart';
import '../../providers/app_providers.dart';
import '../sphere/controller/sphere_controller.dart';
import '../../services/haptic_util.dart';
import '../sphere/widgets/void_sphere.dart';

/// ═══════════════════════════════════════════════════════
/// LOCK SCREEN — the core visual.
///
/// • Giant glowing black sphere sunk at the bottom (barely peeking).
/// • Vertical drag sets the rise *target* instantly; the sphere follows
///   through the LAGGED spring (delay → elastic overshoot → settle with
///   exactly half of it covering the lower half of the screen).
/// • Release above 45% rise → "unlock": sphere settles risen, then this
///   screen hands off to the home pages. Release below → sinks back.
/// • Clock/date rendered in ultra-light Inter over the void.
/// ═══════════════════════════════════════════════════════
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlock});

  /// Called after the unlock animation completes.
  final VoidCallback onUnlock;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  DateTime _now = DateTime.now();
  late final Timer _clock;

  /// Raw drag-driven rise target 0..1 while the finger is down.
  double _dragRise = 0.08;
  bool _unlocking = false;

  static const double _riseRangePx = 260; // px of drag = full travel

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sphereControllerProvider.notifier).sinkRisen();
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _onDragUpdate(double dyDelta) {
    if (_unlocking) return;
    // Dragging UP (negative dy) raises the sphere.
    final double next = (_dragRise - dyDelta / _riseRangePx).clamp(0.0, 1.0);
    if ((next - _dragRise).abs() < 1e-4) return;
    setState(() => _dragRise = next);
    // Feed the *target* only — lag spring creates the trailing motion.
    ref.read(sphereControllerProvider.notifier).setRiseTarget(next);
  }

  Future<void> _onDragEnd() async {
    if (_unlocking) return;
    final SphereController c = ref.read(sphereControllerProvider.notifier);
    if (_dragRise > 0.45) {
      HapticUtil.selection();
      setState(() => _unlocking = true);
      c.setRiseTarget(1.0); // commit: let the spring carry it fully up
      await Future<void>.delayed(const Duration(milliseconds: 620));
      if (!mounted) return;
      widget.onUnlock();
    } else {
      // Not enough intent — sink back with the same heavy lag.
      setState(() => _dragRise = 0.08);
      c.sinkRisen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final double sphereSize = screen.width * 1.6;
    final TextTheme text = VoidTheme.textTheme(context);
    final int page = ref.watch(currentPageProvider);

    return Scaffold(
      backgroundColor: VoidColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (DragUpdateDetails d) =>
            _onDragUpdate(d.delta.dy),
        onVerticalDragEnd: (_) => _onDragEnd(),
        child: Stack(
          children: <Widget>[
            // ── Clock block, fades as the sphere rises ────────────────
            Positioned(
              top: screen.height * 0.12,
              left: 0,
              right: 0,
              child: Column(
                children: <Widget>[
                  Text(
                    _timeString(_now),
                    style: text.displayLarge,
                  ),
                  const SizedBox(height: VoidSpacing.s),
                  Text(_dateString(_now), style: text.labelSmall),
                ],
              ),
            ),
            // ── Hint pill near the bottom (bobs away once dragging) ───
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: sphereSize * 0.16),
                child: AnimatedOpacity(
                  opacity: _dragRise > 0.15 ? 0 : 1,
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    'swipe up',
                    style: text.labelSmall,
                  ),
                ),
              ),
            ),
            // ── THE SPHERE (rendered from lagged physics state) ───────
            Positioned.fill(
              child: _SphereLayer(size: sphereSize),
            ),
            // Page indicator so the lock screen feels connected to home.
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Text('page ${page + 1}', style: text.bodySmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeString(DateTime t) {
    final String h = t.hour.toString().padLeft(2, '0');
    final String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _dateString(DateTime t) {
    const List<String> days = <String>[
      'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
    ];
    const List<String> months = <String>[
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${days[t.weekday - 1]}  ·  ${t.day} ${months[t.month - 1]}';
  }
}

/// Subscribes to the sphere physics state and paints it. Kept isolated so
/// only this layer rebuilds at Ticker rate (the clock/gesture chrome don't).
class _SphereLayer extends ConsumerWidget {
  const _SphereLayer({required this.size});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SphereState s = ref.watch(sphereControllerProvider);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: VoidSphere(
          size: size,
          // LAG value ⇒ delayed, overshooting follow of the rise target.
          rise: s.lag,
          pageX: s.pageX,
          glow: s.glowPulse,
          pressScale: s.pressScale,
          tilt: s.tilt,
        ),
      ),
    );
  }
}

