import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/void_theme.dart';
import '../../../models/installed_app.dart';
import '../../../providers/app_providers.dart';
import '../../sphere/widgets/void_sphere.dart' show MonochromeAppIcon;

/// Minimal search overlay — appears on swipe-down from the top edge or on a
/// tap of the sphere. One hairline input, live results as a dense grid.
class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key});

  static Future<void> open(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'search',
      barrierColor: VoidColors.background.withOpacity(0.96),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const SearchOverlay(),
      transitionBuilder: (
        BuildContext context,
        Animation<double> anim,
        Animation<double> sec,
        Widget child,
      ) =>
          FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final TextEditingController _input = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<InstalledApp> results =
        ref.watch(searchResultsProvider(_query));
    final TextTheme text = VoidTheme.textTheme(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(VoidSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── The search field: just a caret + hairline underline ───
            Row(
              children: <Widget>[
                Icon(Icons.search_rounded,
                    size: 22, color: VoidColors.foreground),
                const SizedBox(width: VoidSpacing.s),
                Expanded(
                  child: TextField(
                    controller: _input,
                    autofocus: true,
                    style: text.headlineMedium?.copyWith(fontSize: 24),
                    decoration: InputDecoration(
                      hintText: 'search',
                      hintStyle: text.headlineMedium?.copyWith(
                        fontSize: 24,
                        color: VoidColors.muted.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (String v) => setState(() => _query = v),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _input.clear();
                      setState(() => _query = '');
                    },
                    child: Icon(Icons.close_rounded,
                        size: 20, color: VoidColors.foreground),
                  ),
              ],
            ),
            Container(height: 1, color: VoidColors.faintLine),
            const SizedBox(height: VoidSpacing.m),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text('nothing in the void', style: text.bodySmall),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: VoidSpacing.l,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: results.length,
                      itemBuilder: (BuildContext context, int i) {
                        final InstalledApp app = results[i];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).pop();
                            ref.read(appLaunchControllerProvider).launch(app);
                          },
                          child: MonochromeAppIcon(
                            size: 52,
                            label: app.appName,
                            iconBytes: app.iconBytes,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
