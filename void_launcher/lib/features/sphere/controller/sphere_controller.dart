import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:void_launcher/models/sphere_state.dart';
import 'package:void_launcher/features/sphere/physics/void_springs.dart';

/// ═══════════════════════════════════════════════════════
/// SPHERE PHYSICS CONTROLLER (Riverpod Notifier)
///
/// The "alive" feeling of the launcher comes from THREE decoupled spring
/// simulations integrated once per Ticker frame (see [SpherePhysicsTicker]):
///
///  ┌───────────────────────────────────────────────────────────────┐
///  │ 1. RISE + LAG                                                 │
///  │    `rise` is the *target* — set instantly by scroll/drag.     │
///  │    `lag` chases `rise` through VoidSprings.lag                │
///  │    (k = 58, ζ = 0.74 ⇒ heavy & underdamped). Because lag      │
///  │    integrates instead of copying, the sphere visibly trails   │
///  │    the finger by ~250 ms and elastically OVERSHOOTS before    │
///  │    settling at "half visible". That is the weight/inertia.    │
///  │                                                               │
///  │ 2. PAGE X                                                     │
///  │    Live drag offset springs back to 0 after each fling; the   │
///  │    committed page index (separate provider) shifts the app    │
///  │    grid while the sphere slides the opposite way.             │
///  │                                                               │
///  │ 3. TILT / PRESS                                               │
///  │    Velocity injects angular momentum into a feather-light     │
///  │    tilt spring; presses set a squish target that relaxes.     │
///  └───────────────────────────────────────────────────────────────┘
/// ═══════════════════════════════════════════════════════
class SphereController extends Notifier<SphereState> {
  @override
  SphereState build() => SphereState.initial;

  // ── Simulation scratch state (velocities persist between frames) ───
  double _lagVelocity = 0; // normalized rise units/sec
  double _pageVelocity = 0; // px/sec
  double _tiltVelocity = 0; // rad/sec
  double _pressTarget = 1.0;

  /// Called once per animation frame by [SpherePhysicsTicker].
  /// [dt] seconds since last frame; [now] monotonic seconds for breathing.
  void step(double dt, {required double now}) {
    if (dt <= 0 || dt > 0.1) return; // ignore hitches / resumed backgrounds

    final SphereState s = state;

    // ── 1. Lagged rise: x'' = -k(x − target) − c·x'  (underdamped) ───
    final SpringSimulation lagSim =
        SpringSimulation(VoidSprings.lag, s.lag, s.rise, _lagVelocity);
    final double nextLag = lagSim.x(dt);
    _lagVelocity = lagSim.dx(dt);

    // ── 2. Page X: springs back toward rest drift = 0 ────────────────
    final SpringSimulation pageSim =
        SpringSimulation(VoidSprings.page, s.pageDragX, 0, _pageVelocity);
    final double nextDrag = pageSim.x(dt);
    _pageVelocity = pageSim.dx(dt);

    // ── 3. Tilt relaxes to level via the feather spring ──────────────
    final SpringSimulation tiltSim =
        SpringSimulation(VoidSprings.feather, s.tilt, 0, _tiltVelocity);
    final double nextTilt = tiltSim.x(dt);
    _tiltVelocity = tiltSim.dx(dt);

    // ── 4. Press scale eases toward its target (fast, no overshoot) ──
    final double nextPress =
        lerpDouble(s.pressScale, _pressTarget, (dt * 14).clamp(0.0, 1.0));

    // ── 5. Glow: idle breathing + energised boost while anything moves ─
    final bool motionSettled = (nextLag - s.rise).abs() <
            VoidSprings.restTolerance &&
        _lagVelocity.abs() < VoidSprings.restTolerance * 60 &&
        nextDrag.abs() < 1.5 &&
        nextPress > 0.999;
    double glow = breatheGlow(now);
    if (!motionSettled) glow = (glow + 0.35).clamp(0.0, 1.0);

    state = s.copyWith(
      lag: nextLag,
      pageDragX: nextDrag.abs() < 0.4 ? 0 : nextDrag,
      tilt: nextTilt,
      pressScale: nextPress,
      glowPulse: glow,
    );
  }

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;

  // ══════════════════ INPUT API (called by gestures) ══════════════════

  /// Instantly move the *target* rise. Scroll drives this directly; the
  /// rendered sphere follows only through the lag spring above.
  void setRiseTarget(double t) {
    state = state.copyWith(rise: t.clamp(0.0, 1.0));
  }

  /// Lock-screen release → settle fully risen (half visible).
  void settleRisen() => setRiseTarget(1.0);

  /// Sink almost fully below the screen (initial peeking state).
  void sinkRisen() => setRiseTarget(0.08);

  /// Live horizontal drag while the finger is down (+dx = dragged right).
  void dragPage(double dx) {
    state = state.copyWith(pageDragX: state.pageDragX + dx);
    // Lean the sphere into the pull — tiny angular impulse.
    _tiltVelocity += (dx / 900).clamp(-0.06, 0.06) * 6;
  }

  /// Finger lifted with velocity [vxPxPerSec]. Commits a page change when
  /// displacement or fling velocity crosses threshold. Returns whether the
  /// page actually moved (caller updates the page index provider).
  ({bool forward, bool changed}) flingPage(
      double vxPxPerSec, double screenWidth) {
    _pageVelocity = vxPxPerSec;
    final double d = state.pageDragX;
    final double threshold = screenWidth * 0.18;
    bool forward = false;
    bool changed = false;
    if (d < -threshold || (d < 0 && vxPxPerSec < -650)) {
      forward = true; // swipe left ⇒ next page (sphere slides right)
      changed = true;
    } else if (d > threshold || (d > 0 && vxPxPerSec > 650)) {
      changed = true; // swipe right ⇒ previous page (sphere slides left)
    }
    // Kick the sphere: it continues in the fling direction, then springs
    // back to center — the elastic recoil sells the mass.
    _pageVelocity = vxPxPerSec * 0.55;
    return (forward: forward, changed: changed);
  }

  /// Press feedback: squish slightly (target relaxes back on release).
  void setPressed(bool pressed) {
    _pressTarget = pressed ? 0.94 : 1.0;
  }

  /// Reset everything (used when re-locking the screen).
  void resetToIdle() {
    _lagVelocity = 0;
    _pageVelocity = 0;
    _tiltVelocity = 0;
    _pressTarget = 1.0;
    state = SphereState.initial;
  }
}

final NotifierProvider<SphereController, SphereState>
    sphereControllerProvider =
    NotifierProvider<SphereController, SphereState>(SphereController.new);

/// Slow breathing glow used at idle — the void is never dead.
double breatheGlow(double tSeconds, {double base = 0.45}) {
  const double period = 3.2;
  final double phase = (tSeconds % period) / period * 2 * math.pi;
  return (base + 0.18 * math.sin(phase)).clamp(0.0, 1.0);
}

/// ═══════════════════════════════════════════════════════
/// THE HEARTBEAT — drives [SphereController.step] every frame.
/// A single Ticker for the whole app keeps physics deterministic and
/// avoids competing AnimationControllers fighting over the same values.
/// ═══════════════════════════════════════════════════════
class SpherePhysicsTicker extends ConsumerStatefulWidget {
  const SpherePhysicsTicker({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SpherePhysicsTicker> createState() =>
      _SpherePhysicsTickerState();
}

class _SpherePhysicsTickerState extends ConsumerState<SpherePhysicsTicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    ref.read(sphereControllerProvider.notifier).step(
          dt,
          now: elapsed.inMicroseconds / 1e6,
        );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
