import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/void_theme.dart';
import '../../../models/installed_app.dart';
import '../../../providers/app_providers.dart';
import '../../sphere/widgets/void_sphere.dart' show MonochromeAppIcon;

/// Full-screen alphabetical app drawer, opened by swiping UP on the sphere.
///
/// Design: frosted white sheet sliding over the home grid, dense 5-column
/// icon field, hairline top divider — monochrome end to end. Uses
/// BouncingScrollPhysics so overscroll feels elastic (consistent with the
/// sphere's spring language).
class AppDrawerSheet extends ConsumerStatefulWidget {
  const AppDrawerSheet({super.key});

  /// Entry point used from HomeScreen via showModalBottomSheet-like route.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        opaque: false,
        barrierColor: Colors.black12,
        pageBuilder: (_, __, ___) => const AppDrawerSheet(),
        transitionsBuilder: (
          BuildContext context,
          Animation<double> anim,
          Animation<double> sec,
          Widget child,
        ) {
          // Slide-up + subtle scale, eased like a heavy object settling.
          final CurvedAnimation c =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(c),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<AppDrawerSheet> createState() => _AppDrawerSheetState();
}

class _AppDrawerSheetState extends ConsumerState<AppDrawerSheet> {
  final ScrollController _scroll = ScrollController();
  String _letter = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<InstalledApp>? apps =
        ref.watch(installedAppsProvider).valueOrNull;
    final TextTheme text = VoidTheme.textTheme(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Swipe DOWN closes the drawer again.
        onVerticalDragEnd: (DragEndDetails d) {
          if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).pop();
        },
        child: Container(
          color: VoidColors.background.withOpacity(0.97),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                // ── Handle bar (grab affordance) ──────────────────────
                Container(
                  margin: const EdgeInsets.only(top: VoidSpacing.s),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VoidColors.foreground.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(VoidSpacing.l, VoidSpacing.m, VoidSpacing.l, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('ALL APPS', style: text.labelSmall),
                      Text(
                        '${apps?.length ?? 0}',
                        style: text.bodySmall
                            ?.copyWith(color: VoidColors.foreground),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: apps == null
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.2,
                              color: VoidColors.foreground,
                            ),
                          ),
                        )
                      : GridView.builder(
                          controller: _scroll,
                          physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.all(VoidSpacing.l),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: VoidSpacing.l,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: apps.length,
                          itemBuilder: (BuildContext context, int i) {
                            final InstalledApp app = apps[i];
                            return Semantics(
                              label: app.appName,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  ref
                                      .read(appLaunchControllerProvider)
                                      .launch(app);
                                },
                                child: MonochromeAppIcon(
                                  size: 52,
                                  label: app.appName,
                                  iconBytes: app.iconBytes,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
