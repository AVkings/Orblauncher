import 'package:flutter/material.dart';

import '../../../core/theme/void_theme.dart';
import '../../../models/installed_app.dart';
import '../../sphere/widgets/void_sphere.dart' show MonochromeAppIcon;

/// One home-screen page: a 4-column grid of monochrome app tiles.
///
/// The grid itself is static — all motion (parallax, fade) is applied by
/// the parent through Transform effects driven by the sphere's spring, so
/// pages and sphere share one physics clock and never desync.
class AppPageGrid extends StatelessWidget {
  const AppPageGrid({
    super.key,
    required this.apps,
    required this.columns,
    required this.onTapApp,
    this.onLongPressApp,
  });

  final List<InstalledApp> apps;
  final int columns;
  final void Function(InstalledApp app) onTapApp;
  final void Function(InstalledApp app)? onLongPressApp;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(VoidSpacing.l, 0, VoidSpacing.l,
          MediaQuery.of(context).size.width * 0.62),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: VoidSpacing.l,
        childAspectRatio: 0.78,
      ),
      itemCount: apps.length,
      itemBuilder: (BuildContext context, int index) {
        final InstalledApp app = apps[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTapApp(app),
          onLongPress:
              onLongPressApp == null ? null : () => onLongPressApp!(app),
          child: MonochromeAppIcon(
            size: 58,
            label: app.appName,
            iconBytes: app.iconBytes,
          ),
        );
      },
    );
  }
}
