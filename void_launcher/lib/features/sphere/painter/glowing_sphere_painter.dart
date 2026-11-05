import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// ═══════════════════════════════════════════════════════
/// GLOWING SPHERE PAINTER (CustomPainter — no static images)
///
/// Rendering recipe, back-to-front:
///   1. OUTER HALO   — a wide radial gradient (transparent → soft black)
///                     painted *behind* the body. On pure white this reads
///                     as an atmospheric glow/shadow field around the moon.
///                     Its radius & alpha breathe with [glow] (0..1).
///   2. BODY         — solid deep-black disc.
///   3. RIM LIGHT    — an arc stroked with a sweep-gradient that fades in
///                     near the top edge: the "black moon with rim light".
///   4. SPECULAR     — a small offset radial highlight (white → clear),
///                     giving the void sphere a glassy, premium finish.
///
/// All parameters are plain doubles so the painter can be driven directly
/// by spring-simulation values every frame without allocations.
/// ═══════════════════════════════════════════════════════
class GlowingSpherePainter extends CustomPainter {
  const GlowingSpherePainter({
    required this.glow,
    required this.pressScale,
    this.bodyColor = const Color(0xFF000000),
  });

  /// 0..1 — halo intensity/size + specular brightness.
  final double glow;

  /// ~0.94 while pressed (squish), 1.0 at rest.
  final double pressScale;

  final Color bodyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    // The layout guarantees a square-ish layer; clamp to fit.
    final double radius =
        math.min(size.width, size.height) / 2 * pressScale;
    if (radius <= 0) return;

    // ── 1. Outer halo (soft black aura on white) ──────────────────────
    final double haloRadius = radius * (1.35 + 0.45 * glow);
    final Paint halo = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          bodyColor.withOpacity(0.0),
          bodyColor.withOpacity(0.06 + 0.10 * glow), // mid falloff
          bodyColor.withOpacity(0.0),
        ],
        stops: const <double>[0.72, 0.86, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: haloRadius));
    canvas.drawCircle(center, haloRadius, halo);

    // Tight inner bloom hugging the silhouette (the bright "atmosphere").
    final Paint bloom = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          bodyColor.withOpacity(0.0),
          Colors.white.withOpacity(0.9), // rim of pure white between halos
          bodyColor.withOpacity(0.14 + 0.12 * glow),
        ],
        stops: <double>[0.80, 0.965 - 0.01 * glow, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.16));
    canvas.drawCircle(center, radius * 1.16, bloom);

    // ── 2. Solid body ─────────────────────────────────────────────────
    canvas.drawCircle(center, radius, Paint()..color = bodyColor);

    // ── 3. Rim light: upper-left crescent, like eclipse atmosphere ────
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 + 1.4 * glow
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        begin: 0,
        end: 1,
        colors: <Color>[
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.55 + 0.35 * glow),
          Colors.white.withOpacity(0.0),
        ],
        stops: const <double>[0.55, 0.78, 1.0],
        transform: const GradientRotation(math.pi * 0.9),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - rim.strokeWidth / 2),
      math.pi * 0.75, // start bottom-left…
      math.pi * 1.15, // …sweep over the top — the lit hemisphere edge
      false,
      rim,
    );

    // ── 4. Specular highlight (offset soft white blob inside the body) ─
    final Offset specCenter =
        center + Offset(-radius * 0.32, -radius * 0.42);
    final Paint spec = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withOpacity(0.10 + 0.14 * glow),
          Colors.white.withOpacity(0.0),
        ],
        stops: const <double>[0.0, 1.0],
      ).createShader(Rect.fromCircle(
          center: specCenter, radius: radius * 0.55));
    canvas.drawCircle(specCenter, radius * 0.55, spec);
  }

  @override
  bool shouldRepaint(GlowingSpherePainter old) =>
      old.glow != glow || old.pressScale != pressScale;

  @override
  bool shouldRebuildSemantics(CustomPainter oldDelegate) => false;
}
