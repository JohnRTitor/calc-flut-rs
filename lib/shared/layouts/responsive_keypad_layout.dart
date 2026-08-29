import 'package:flutter/material.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';

/// A standardized layout engine for screens that contain a top display area
/// and a bottom keypad area (e.g., calculators, converters).
///
/// Automatically handles constrained vertical space (e.g., split-screen, landscape)
/// by switching from a rigid Flex layout to a scrollable layout, preventing the
/// keypad and display from becoming unreadably compressed.
class ResponsiveKeypadLayout extends StatelessWidget {
  /// The top section of the screen, usually containing results, inputs, and charts.
  final Widget displayArea;

  /// The bottom section of the screen, usually containing a numeric keypad or controls.
  final Widget keypad;

  /// The flex value for the display area when unconstrained (default: 55).
  final int displayFlex;

  /// The flex value for the keypad when unconstrained (default: 45).
  final int keypadFlex;

  /// The minimum height the keypad should maintain in constrained mode.
  /// If null, defaults to 350 for most utilities or 450 for the main calculator.
  final double? keypadMinHeight;

  const ResponsiveKeypadLayout({
    super.key,
    required this.displayArea,
    required this.keypad,
    this.displayFlex = 55,
    this.keypadFlex = 45,
    this.keypadMinHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.isShortScreen) {
          // Constrained Height: Fallback to scrolling to preserve usability.
          return SingleChildScrollView(
            child: Column(
              children: [
                // We do not restrict the display area's height here, allowing it to size to its content
                displayArea,

                // Keep the keypad at a readable size and ensure it sits above the system nav bar
                SafeArea(
                  top: false,
                  bottom: true,
                  child: SizedBox(
                    height: keypadMinHeight ?? 350,
                    child: keypad,
                  ),
                ),
              ],
            ),
          );
        }

        // Normal Height: Display area shrinks to content (up to its max proportion),
        // while the keypad expands to fill all remaining space.
        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    constraints.maxHeight *
                    (displayFlex / (displayFlex + keypadFlex)),
              ),
              child: displayArea,
            ),
            Expanded(child: SafeArea(top: false, bottom: true, child: keypad)),
          ],
        );
      },
    );
  }
}
