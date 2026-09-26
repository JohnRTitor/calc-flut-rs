import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_workspace_layout.dart';

/// A fixed-height stand-in for one of a screen's two areas, identified by
/// colour so the two can be found apart in a single tree.
class _Box extends StatelessWidget {
  final double height;
  final int color;

  const _Box({required this.height, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ColoredBox(color: Color(color)),
  );
}

void main() {
  /// Sizes the test surface to [width] x [height].
  ///
  /// Necessary because the default test surface is 800x600, which is *shorter*
  /// than [AppBreakpoints.shortScreenMaxHeight]. Without this, every "tall"
  /// layout silently takes the short-screen branch and the height assertions
  /// end up measuring the fallback instead of the arrangement under test.
  void useSurface(WidgetTester tester, double width, double height) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
  }

  Widget host({
    required double width,
    required double height,
    required bool pinControls,
    double displayHeight = 100,
    double controlsHeight = 60,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: ResponsiveWorkspaceLayout(
            displayArea: _Box(height: displayHeight, color: 0xFF00FF00),
            controls: _Box(height: controlsHeight, color: 0xFFFF0000),
            pinControls: pinControls,
            controlsMinHeight: 200,
            gap: const SizedBox(height: 8),
          ),
        ),
      ),
    );
  }

  Finder display() =>
      find.byWidgetPredicate((w) => w is _Box && w.color == 0xFF00FF00);
  Finder controls() =>
      find.byWidgetPredicate((w) => w is _Box && w.color == 0xFFFF0000);

  group('pinned controls', () {
    // The calculator's arrangement: the keys stay under the thumb and the
    // display area takes whatever is left.
    testWidgets('fill the available height between them', (tester) async {
      useSurface(tester, 400, 800);
      await tester.pumpWidget(host(width: 400, height: 800, pinControls: true));
      await tester.pumpAndSettle();

      expect(tester.getSize(display()).height, 100);
      // Display 100, gap 8, and the controls expand into the remaining 692.
      expect(tester.getSize(controls()).height, 692);
    });

    testWidgets('stay pinned as the display area grows', (tester) async {
      useSurface(tester, 400, 2000);
      await tester.pumpWidget(
        host(width: 400, height: 2000, pinControls: true),
      );
      await tester.pumpAndSettle();

      // The display area is capped at its flex share, so a tall window does
      // not leave the keys stranded halfway down the screen.
      expect(
        tester.getSize(display()).height,
        lessThanOrEqualTo(2000 * (55 / 100) + 0.5),
      );
      expect(
        tester.getSize(controls()).height,
        greaterThan(0),
        reason: 'the controls must still be on screen',
      );
    });
  });

  group('unpinned controls', () {
    // The Function Evaluator's arrangement, and the fix for its dead space.
    testWidgets('sit directly below the display area', (tester) async {
      useSurface(tester, 400, 800);
      await tester.pumpWidget(
        host(width: 400, height: 800, pinControls: false),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(controls()).dy,
        closeTo(tester.getBottomLeft(display()).dy + 8, 0.5),
        reason:
            'the controls must follow the content they act on, not be pushed '
            'to the bottom of whatever the viewport happens to be',
      );
    });

    testWidgets('do not expand to fill a tall viewport', (tester) async {
      useSurface(tester, 400, 800);
      await tester.pumpWidget(
        host(width: 400, height: 800, pinControls: false),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(controls()).height,
        60,
        reason: 'a content-sized control area is what removes the dead zone',
      );
    });

    // A normal-height screen whose result is far taller than the viewport —
    // the case a data-dense analysis grid produces.
    testWidgets('scroll when the content exceeds the viewport', (tester) async {
      const height = 700.0;
      useSurface(tester, 400, height);
      await tester.pumpWidget(
        host(
          width: 400,
          height: height,
          pinControls: false,
          displayHeight: 900,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(controls()).dy,
        greaterThan(height),
        reason: 'the controls start below the fold',
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(controls()).dy,
        lessThan(height),
        reason: 'and scrolling must bring them into reach',
      );
    });
  });

  group('short screens', () {
    // Below the threshold a rigid two-pane split compresses both sides into
    // illegibility, so both arrangements fall back to one scroll and the
    // controls keep a readable floor.
    for (final pin in [true, false]) {
      testWidgets('fall back to a scroll when pinControls is $pin', (
        tester,
      ) async {
        final short = AppBreakpoints.shortScreenMaxHeight - 50;
        useSurface(tester, 400, short);
        await tester.pumpWidget(
          host(width: 400, height: short, pinControls: pin),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(
          tester.getSize(controls()).height,
          200,
          reason:
              'the controls keep their minimum height rather than being '
              'compressed by the display area',
        );
      });
    }

    testWidgets('is not used on a normal screen', (tester) async {
      final tall = AppBreakpoints.shortScreenMaxHeight + 50;
      useSurface(tester, 400, tall);
      await tester.pumpWidget(
        host(width: 400, height: tall, pinControls: true),
      );
      await tester.pumpAndSettle();

      // The inherited short-screen fallback must not fire above the threshold,
      // or every ordinary phone would get a scrolling keypad.
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('widths', () {
    // AC-7: the three shell breakpoints must all lay out cleanly. The layout
    // has no width-dependent behaviour of its own yet, but it is the container
    // every migrated screen sits in, so an overflow at any of these widths is
    // worth pinning.
    const widths = {
      'compact (< 600)': 360.0,
      'medium (600-840)': 720.0,
      'expanded (> 840)': 1200.0,
    };
    widths.forEach((name, width) {
      testWidgets('lays out at $name', (tester) async {
        useSurface(tester, width, 700);
        await tester.pumpWidget(
          host(width: width, height: 700, pinControls: false),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(display(), findsOneWidget);
        expect(controls(), findsOneWidget);
      });
    });
  });

  testWidgets('applies its padding around the whole layout', (tester) async {
    useSurface(tester, 400, 800);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: ResponsiveWorkspaceLayout(
              displayArea: const _Box(height: 100, color: 0xFF00FF00),
              controls: const _Box(height: 60, color: 0xFFFF0000),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(display()).dx,
      12,
      reason: "the caller's padding must actually be applied",
    );
  });

  testWidgets('survives a window measured at zero', (tester) async {
    useSurface(tester, 400, 600);
    await tester.pumpWidget(host(width: 400, height: 0, pinControls: false));
    expect(tester.takeException(), isNull);
  });
}
