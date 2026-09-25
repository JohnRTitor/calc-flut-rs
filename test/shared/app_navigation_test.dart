import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/app_hub_grid.dart';
import 'package:calc_flut_rs/shared/widgets/app_navigation.dart';

const List<AppNavDestination> _destinations = [
  AppNavDestination(id: 'calculator', label: 'Calculator', icon: Icons.calculate),
  AppNavDestination(
    id: 'converter',
    label: 'Converter',
    icon: Icons.swap_horiz,
  ),
  AppNavDestination(id: 'history', label: 'History', icon: Icons.history),
];

Widget _host(UiStyle uiStyle, Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
    home: Scaffold(body: child),
  );
}

void main() {
  for (final uiStyle in UiStyle.values) {
    group('AppNavigationDrawer ($uiStyle)', () {
      testWidgets('renders every destination and reports the tapped id', (
        tester,
      ) async {
        String? tapped;

        await tester.pumpWidget(
          _host(
            uiStyle,
            Builder(
              builder: (context) => Scaffold(
                body: Builder(
                  builder: (context) => AppNavigationDrawer(
                    uiStyle: uiStyle,
                    destinations: _destinations,
                    selectedId: 'converter',
                    onSelected: (id) => tapped = id,
                  ),
                ),
              ),
            ),
          ),
        );

        for (final destination in _destinations) {
          expect(find.text(destination.label), findsOneWidget);
        }

        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        expect(tapped, 'history');
      });

      testWidgets('exposes the selected destination to screen readers', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AppNavigationDrawer(
              uiStyle: uiStyle,
              destinations: _destinations,
              selectedId: 'converter',
              onSelected: (_) {},
            ),
          ),
        );

        // The Semantics wrapper on each tile must announce it as a selected
        // button with an accessible label, for both UI styles.
        final selected = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere(
              (node) => node.properties.label == 'Converter',
            );

        expect(selected.properties.button, isTrue);
        expect(selected.properties.selected, isTrue);

        final unselected = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((node) => node.properties.label == 'Calculator');

        expect(unselected.properties.button, isTrue);
        expect(unselected.properties.selected, isFalse);
      });
    });

    group('AppNavigationRail ($uiStyle)', () {
      for (final extended in [false, true]) {
        testWidgets(
          extended ? 'extended rail shows labels' : 'collapsed rail hides labels',
          (tester) async {
            var tapped = '';

            await tester.pumpWidget(
              _host(
                uiStyle,
                SizedBox(
                  width: extended ? 200 : 80,
                  child: AppNavigationRail(
                    uiStyle: uiStyle,
                    destinations: _destinations,
                    selectedId: 'calculator',
                    extended: extended,
                    onSelected: (id) => tapped = id,
                  ),
                ),
              ),
            );

            // The collapsed rail is icon-only; the extended rail paints the
            // label next to every icon.
            expect(
              find.text('Calculator'),
              extended ? findsOneWidget : findsNothing,
            );
            expect(
              find.text('Converter'),
              extended ? findsOneWidget : findsNothing,
            );
            expect(find.byIcon(Icons.calculate), findsOneWidget);

            await tester.tap(find.byIcon(Icons.swap_horiz));
            await tester.pumpAndSettle();

            expect(tapped, 'converter');
          },
        );
      }

      testWidgets('is operable from the keyboard', (tester) async {
        var tapped = '';

        await tester.pumpWidget(
          _host(
            uiStyle,
            SizedBox(
              width: 80,
              child: AppNavigationRail(
                uiStyle: uiStyle,
                destinations: _destinations,
                selectedId: 'calculator',
                onSelected: (id) => tapped = id,
              ),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(tapped, 'calculator');
      });
    });

    group('AppHubGrid ($uiStyle)', () {
      testWidgets('renders a card per item and fires onTap', (tester) async {
        var tapped = '';

        await tester.pumpWidget(
          _host(
            uiStyle,
            AppHubGrid(
              uiStyle: uiStyle,
              items: [
                AppHubGridItem(
                  id: 'length',
                  label: 'Length',
                  icon: Icons.straighten,
                  onTap: () => tapped = 'length',
                ),
                AppHubGridItem(
                  id: 'mass',
                  label: 'Mass',
                  icon: Icons.scale,
                  onTap: () => tapped = 'mass',
                ),
              ],
            ),
          ),
        );

        expect(find.text('Length'), findsOneWidget);
        expect(find.text('Mass'), findsOneWidget);

        await tester.tap(find.text('Mass'));
        await tester.pumpAndSettle();

        expect(tapped, 'mass');
      });

      testWidgets('renders an empty state with no items', (tester) async {
        await tester.pumpWidget(
          _host(uiStyle, AppHubGrid(uiStyle: uiStyle, items: const [])),
        );

        expect(find.text('No tools available yet.'), findsOneWidget);
      });
    });
  }
}
