/// Immutable snapshot of everything the sphere renders from.
///
/// The sphere widget is a *pure function* of this state plus a slow
/// "lag" spring value — no imperative animation calls anywhere.
class SphereState {
  const SphereState({
    required this.rise, // 0 = sunk below the screen, 1 = settled (half visible)
    required this.lag, // 0..1 spring-driven copy of [rise], deliberately delayed
    required this.pageDragX, // live horizontal drag in logical px (+ = right)
    required this.pageSettleX, // resting page offset after a fling settles
    required this.pressScale, // 1.0 idle, <1 while pressed (squish feedback)
    required this.glowPulse, // 0..1 breathing / interaction glow intensity
    required this.tilt, // radians — subtle rotation reacting to velocity
  });

  static const SphereState initial = SphereState(
    rise: 0.0,
    lag: 0.0,
    pageDragX: 0.0,
    pageSettleX: 0.0,
    pressScale: 1.0,
    glowPulse: 0.5,
    tilt: 0.0,
  );

  /// Total horizontal translation of the sphere body.
  double get pageX => pageDragX + pageSettleX;

  SphereState copyWith({
    double? rise,
    double? lag,
    double? pageDragX,
    double? pageSettleX,
    double? pressScale,
    double? glowPulse,
    double? tilt,
  }) {
    return SphereState(
      rise: rise ?? this.rise,
      lag: lag ?? this.lag,
      pageDragX: pageDragX ?? this.pageDragX,
      pageSettleX: pageSettleX ?? this.pageSettleX,
      pressScale: pressScale ?? this.pressScale,
      glowPulse: glowPulse ?? this.glowPulse,
      tilt: tilt ?? this.tilt,
    );
  }
}
