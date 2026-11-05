import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/void_theme.dart';
import '../painter/glowing_sphere_painter.dart';

/// ═══════════════════════════════════════════════════════
/// THE SPHERE — a giant glowing black moon.
///
/// This widget is intentionally "dumb": it renders from externally-driven
/// physics values (see SphereController). No imperative animation lives
/// here — every number below comes from a spring simulation tick:
///
///   rise      → vertical position 0..1. The sphere's CENTER travels from
///               below the bottom edge (barely peeking, 0) to exactly ON
///               the bottom edge (HALF visible, 1). The controller feeds
///               this widget its *lagged* value, so the sphere trails the
///               finger and elastically overshoots before settling.
///
///   pageX     → horizontal translation in logical px (+ = right), driven
///               by the page spring during swipe navigation.
///
///   glow      → halo intensity (breathes at idle, energised while moving).
///
///   pressScale / tilt → micro-reactions (squish + lean) fed by gestures.
/// ═══════════════════════════════════════════════════════
class VoidSphere extends StatelessWidget {
  const VoidSphere({
    super.key,
    required this.size,
    required this.rise,
    required this.pageX,
    required this.glow,
    this.pressScale = 1.0,
    this.tilt = 0.0,
  });

  /// Diameter of the sphere in logical pixels (giant ⇒ ~1.6× screen width).
  final double size;
  final double rise; // 0..1 (may briefly overshoot >1 via spring)
  final double pageX; // px
  final double glow; // 0..1
  final double pressScale;
  final double tilt; // radians

  @override
  Widget build(BuildContext context) {
    // Vertical anchor math (dy = downward offset of the sphere box):
    //   rise = 0  → dy = +0.55·size  → center sits BELOW the bottom edge,
    //                                  only a sliver peeks up from below.
    //   rise = 1  → dy = 0           → center sits exactly ON the bottom
    //                                  edge ⇒ HALF of the sphere covers
    //                                  the lower half of the screen.
    // Spring overshoot (rise slightly > 1) lifts it a touch past the
    // settle point — that elastic bob is the audible-free "weight".
    final double r = rise.clamp(-0.25, 1.35);
    final double dy = size * (0.55 - 0.55 * r);
    return Transform.translate(
      offset: Offset(pageX, dy),
      child: Transform.rotate(
        angle: tilt,
        alignment: Alignment.center,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: GlowingSpherePainter(glow: glow, pressScale: pressScale),
          ),
        ),
      ),
    );
  }
}

/// Slow breathing glow used when the user is idle — the void is never dead.
double breatheGlow(double tSeconds, {double base = 0.45}) {
  const double period = 3.2; // seconds per breath
  final double phase = (tSeconds % period) / period * 2 * math.pi;
  return (base + 0.18 * math.sin(phase)).clamp(0.0, 1.0);
}

/// Soft-shadow wrapper giving tap targets a subtle halo on white.
class GlowRing extends StatelessWidget {
  const GlowRing({super.key, required this.child, this.active = false});
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(active ? 0.25 : 0.08),
            blurRadius: active ? 32 : 18,
            spreadRadius: active ? 4 : 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Monochrome app icon tile: real launcher icon inside a black disc; falls
/// back to a white initial glyph when icon bytes are unavailable.
class MonochromeAppIcon extends StatelessWidget {
  const MonochromeAppIcon({
    super.key,
    required this.size,
    required this.label,
    this.iconBytes,
  });

  final double size;
  final String label;
  final Uint8List? iconBytes;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? img =
        iconBytes == null ? null : MemoryImage(iconBytes!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: VoidColors.foreground,
            shape: BoxShape.circle,
            boxShadow: VoidColors.softShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: img == null
              ? Center(
                  child: Text(
                    label.isNotEmpty ? label[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: VoidColors.background,
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                )
              : Opacity(opacity: 0.9, child: Image(image: img, fit: BoxFit.cover)),
        ),
        const SizedBox(height: VoidSpacing.s),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VoidColors.foreground,
              ),
        ),
      ],
    );
  }
}
