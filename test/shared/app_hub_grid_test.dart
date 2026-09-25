import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/app_hub_grid.dart';

const List<AppHubGridItem> _items = [
  AppHubGridItem(
    id: 'algebra',
    label: 'Algebra',
    icon: Icons.functions,
    onTap: _noop,
  ),
  AppHubGridItem(
    id: 'calculus',
    label: 'Calculus',
    icon: Icons.show_chart,
    onTap: _noop,
  ),
  AppHubGridItem(
    id: 'matrices',
    label: 'Matrices',
    icon: Icons.grid_on,
    onTap: _noop,
  ),
];

void _noop() {}

/// Mirrors how the shell hosts a section root: a viewport inside an
/// IndexedStack, which builds every child on the first frame.
Widget _host(UiStyle uiStyle, int index) {
  return MaterialApp(
    theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
    home: Scaffold(
      body: IndexedStack(
        sizing: StackFit.expand,
        index: index,
        children: [
          AppHubGrid(uiStyle: uiStyle, items: const []),
          AppHubGrid(uiStyle: uiStyle, items: _items),
        ],
      ),
    ),
  );
}

void main() {
  // Regression: the shell builds every IndexedStack child on the very first
  // frame, when the window can still measure zero on Android while insets
  // settle. A viewport given a non-positive cross-axis extent makes
  // SliverGridDelegateWithMaxCrossAxisExtent assert
  // (`crossAxisExtent > 0.0`) and then cascades into null-check errors.
  //
  // Swept rather than sampled, so a threshold that is merely "not quite right"
  // cannot slip through between the sample points.
  for (final uiStyle in UiStyle.values) {
    for (final extent in <double>[
      0,
      0.5,
      1,
      8,
      24,
      48,
      64,
      96,
      128,
      150,
      199,
      200,
      240,
      320,
      480,
    ]) {
      testWidgets('survives a $extent x $extent window ($uiStyle)', (
        tester,
      ) async {
        tester.view.physicalSize = Size.square(extent);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(uiStyle, 1));
        await tester.pumpAndSettle();

        // A sliver assertion or a RenderFlex overflow is reported as a
        // FlutterError, so assert on it explicitly rather than relying on
        // pumpAndSettle alone to throw.
        expect(tester.takeException(), isNull);
      });
    }
  }

  // The guard must actually skip the grid rather than render an unusable one:
  // too small means no grid at all, not a grid whose cards overflow.
  for (final uiStyle in UiStyle.values) {
    testWidgets('renders nothing when there is no room for a card ($uiStyle)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(128, 128);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(uiStyle, 1));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final uiStyle in UiStyle.values) {
    testWidgets('renders a card per item once there is room ($uiStyle)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(uiStyle, 1));
      await tester.pumpAndSettle();

      for (final item in _items) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('fires onTap for the tapped card ($uiStyle)', (tester) async {
      var tapped = '';
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(
            null,
            uiStyle,
            AppColorOption.defaultColor,
          ),
          home: AppHubGrid(
            uiStyle: uiStyle,
            items: [
              for (final item in _items)
                AppHubGridItem(
                  id: item.id,
                  label: item.label,
                  icon: item.icon,
                  onTap: () => tapped = item.id,
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Matrices'));
      await tester.pumpAndSettle();

      expect(tapped, 'matrices');
    });

    testWidgets('renders an empty state with no items ($uiStyle)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(uiStyle, 0));
      await tester.pumpAndSettle();

      expect(find.text('No tools available yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
