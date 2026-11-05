import 'package:flutter/material.dart';

import '../../../core/theme/void_theme.dart';

/// Ultra-minimal pagination indicator: thin black line segments on white.
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.count,
    required this.current,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 22 : 8,
            height: 2,
            decoration: BoxDecoration(
              color: i == current
                  ? VoidColors.foreground
                  : VoidColors.foreground.withOpacity(0.22),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}
