import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_state.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/calculator_screen.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/modular_arithmetic_workspace_screen.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/structure_explorer.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/algebra_screen.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';

/// The real notifier's `build` reads memory through the Rust bridge, which
/// cannot run in a Dart-only test. The calculator renders from its own state,
/// so an empty one exercises the layout faithfully.
class _OfflineCalculator extends Calculator {
  @override
  CalculatorState build() => const CalculatorState();
}

/// Stands in for the real history notifier, which reads through the bridge.
class _EmptyHistory extends History {
  @override
  Future<List<HistoryEntry>> build() async => const [];
}

/// Pins the UI style. Necessary rather than cosmetic: screens read their style
/// from this provider, not from the theme, so building a glass `AppTheme` alone
/// would render the Material branch and quietly "pass" the glass half.
class _PinnedUiStyle extends UiStyleNotifier {
  _PinnedUiStyle(this.style);

  final UiStyle style;

  @override
  UiStyle build() => style;
}

/// Sizes named for the shell's own breakpoints, so a failure says which layout
/// regime broke rather than just a number.
const _surfaces = <String, Size>{
  'compact, under 600': Size(400, 800),
  'medium, 600 to 840': Size(720, 800),
  'expanded, over 840': Size(1200, 800),
  // Below AppBreakpoints.shortScreenMaxHeight (650): the regime where a rigid
  // two-pane split would compress both panes, and the one most likely to
  // overflow because the scroll fallback has to take over at the last moment.
  'short screen, under 650 tall': Size(800, 500),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget themed(Widget child, UiStyle uiStyle) {
    return MaterialApp(
      theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
      home: Scaffold(body: child),
    );
  }

  for (final uiStyle in UiStyle.values) {
    final styleName = uiStyle == UiStyle.material ? 'material' : 'liquidGlass';

    // Every screen the redesign moved onto the shared workspace layout.
    //
    // All four need the history stand-in: above the expanded breakpoint each
    // renders `RecentHistoryPanel` as its side panel, and the real history
    // notifier reads through the bridge, so without this the panel sits on an
    // indeterminate spinner forever. That is invisible at compact and medium
    // widths, which is why it only shows up in the expanded column.
    //
    // `ModularArithmeticWorkspace` and `SymbolicWorkspace` both build a
    // constant state without touching the bridge, so those two need no stand-in
    // for their own state — a direct check that they are offline-safe as
    // written.
    final screens = <String, Widget>{
      'CalculatorScreen': const CalculatorScreen(),
      'ModularArithmeticWorkspaceScreen':
        const ModularArithmeticWorkspaceScreen(),
      'StructureExplorer': const StructureExplorer(),
      'AlgebraScreen': const AlgebraScreen(),
    };

    for (final entry in screens.entries) {
      group('${entry.key} ($styleName)', () {
        for (final surface in _surfaces.entries) {
          testWidgets('lays out without overflow at ${surface.key}', (
            tester,
          ) async {
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = surface.value;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  uiStyleProvider.overrideWith(() => _PinnedUiStyle(uiStyle)),
                  historyProvider.overrideWith(_EmptyHistory.new),
                  // The calculator's own notifier reads memory through the
                  // bridge; the screen renders from its state, so an empty one
                  // exercises the layout faithfully.
                  if (entry.key == 'CalculatorScreen')
                    calculatorProvider.overrideWith(_OfflineCalculator.new),
                ],
                child: themed(entry.value, uiStyle),
              ),
            );
            await tester.pumpAndSettle();

            // A RenderFlex overflow surfaces as a framework error, so this is
            // the assertion that actually catches a broken layout rather than
            // merely confirming the screen built.
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${entry.key} overflowed at '
                  '${surface.value.width}x${surface.value.height} in $styleName',
            );
          });
        }
      });
    }
  }
}
