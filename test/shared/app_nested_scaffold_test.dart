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

Widget _app(UiStyle uiStyle, List<Widget> children, int index) {
  return MaterialApp(
    theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
    home: Scaffold(
      body: IndexedStack(
        sizing: StackFit.expand,
        index: index,
        children: children,
      ),
    ),
  );
}

Widget _grid(UiStyle uiStyle) {
  return AppHubGrid(uiStyle: uiStyle, items: _items);
}

void main() {
  // Regression: AppHubGrid is hosted inside the shell's IndexedStack, which
  // builds every section root on the very first frame — when the window can
  // still measure zero on Android while insets settle. A viewport given a
  // non-positive cross-axis extent makes
  // SliverGridDelegateWithMaxCrossAxisExtent assert
  // (`crossAxisExtent > 0.0`) and then cascades into null-check errors.
  for (final uiStyle in UiStyle.values) {
    for (final size in <Size>[
      Size.zero,
      const Size(0.5, 0.5),
      const Size(1, 1),
      const Size(24, 24),
      const Size(48, 48),
      const Size(320, 480),
    ]) {
      testWidgets('hub grid survives $size ($uiStyle)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(uiStyle, [_grid(uiStyle), _grid(uiStyle)], 1),
        );

        // Any degenerate-constraint assertion surfaces here.
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('hub grid renders cards once real space is available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(UiStyle.material, [_grid(UiStyle.material)], 0));
    await tester.pumpAndSettle();

    for (final item in _items) {
      expect(find.text(item.label), findsOneWidget);
    }
  });
}
