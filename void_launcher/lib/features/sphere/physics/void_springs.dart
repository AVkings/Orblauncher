import 'package:flutter/physics.dart';

/// ═══════════════════════════════════════════════════════
/// SPRING PRESETS — the "weight" of the sphere lives here.
///
/// Flutter's [SpringSimulation] integrates:
///   a = -k * (x - target) - c * v      (Hooke + damping)
/// with mass implicitly 1. Lower stiffness / higher damping ratio
/// ⇒ slower, heavier, more organic settle. That is exactly the
/// "lagged physics feel" the lock screen needs.
/// ═══════════════════════════════════════════════════════
class VoidSprings {
  VoidSprings._();

  /// Stiffness (spring constant k).
  static const double _k = 58;

  /// Damping coefficient c = 2 * zeta * sqrt(k * m), with m = 1.
  /// zeta < 1 ⇒ underdamped ⇒ the sphere overshoots then settles.
  /// k = 58, zeta = 0.74 ⇒ c ≈ 11.3 (hand-computed constant below).
  static const double _lagDamping = 11.3;

  /// The signature LAG spring: deliberately slow + bouncy. Used for the
  /// sphere's vertical rise so it trails the user's scroll by ~250ms and
  /// elastically overshoots before settling at "half visible".
  static const SpringDescription lag = SpringDescription(
    mass: 1.0,
    stiffness: _k,
    damping: _lagDamping,
  );

  /// Snappier sibling used for horizontal page transitions — still
  /// underdamped (a hint of bounce) but fast enough to feel responsive.
  static SpringDescription get page => const SpringDescription(
        mass: 1.0,
        stiffness: 160,
        damping: 20,
      );

  /// Very light spring for glow/scale micro-reactions (near weightless).
  static SpringDescription get feather => const SpringDescription(
        mass: 1.0,
        stiffness: 320,
        damping: 26,
      );

  /// Rest threshold — stop integrating when |x-target| & |v| are below this.
  static const double restTolerance = 0.0015;
}
