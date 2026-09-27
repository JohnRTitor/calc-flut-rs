import 'package:flutter/material.dart';

import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';

/// The shared layout for every "enter something, see a result, act on it" screen.
///
/// Four screens in this app had that same shape and each had solved it
/// differently: the calculator's [ResponsiveKeypadLayout] capped a display area
/// and expanded a control area, the Function Evaluator put a bare `Spacer()`
/// between its editor and its result so the result fell to the bottom of
/// whatever viewport it happened to be in, and the two Modular Arithmetic tabs
/// — one `AnimatedSwitcher` apart — disagreed about whether the primary button
/// stayed pinned while the results scrolled. Four places to get overflow right,
/// and they had already drifted apart.
///
/// This resolves the two decisions a screen actually has to make:
///
/// * **does the primary action stay put?** [pinControls]. Pinned means the
///   control area keeps its own space and only the display area scrolls, which
///   suits a fixed instrument like a numeric keypad where the keys must always
///   be under the same thumb. Unpinned means the whole screen is one
///   content-sized scroll, which suits a data-dense result whose height nobody
///   can predict — pinning a button under a variable-height results grid is what
///   produces the awkward fixed-height footer.
/// * **how does the display area size itself?** [displayFlex] and
///   [controlsMinHeight] express that as a proportion and a floor, so a screen
///   that wants "the rest of the space" and one that wants "at most half" share
///   the same code.
///
/// The short-screen fallback is inherited unchanged from
/// [ResponsiveKeypadLayout]: below [AppBreakpoints.shortScreenMaxHeight] a rigid
/// two-pane split compresses both sides into illegibility, so the screen
/// becomes a single scroll and the controls keep a readable minimum height.
class ResponsiveWorkspaceLayout extends StatelessWidget {
  /// The inputs, results and charts. Sized to its content up to [displayFlex]
  /// of the available height.
  final Widget displayArea;

  /// The keypad, or the actions that commit the work.
  final Widget controls;

  /// Whether [controls] holds its place while [displayArea] scrolls, rather
  /// than scrolling away with the content.
  final bool pinControls;

  /// Share of the unconstrained height [displayArea] may occupy.
  final int displayFlex;

  /// Share of the unconstrained height [controls] occupies when
  /// [pinControls] is true. Ignored otherwise, since an unpinned control area
  /// sizes to its own content.
  final int controlsFlex;

  /// Height floor for [controls] on a short screen, where it is given a fixed
  /// box rather than being compressed.
  final double controlsMinHeight;

  /// Insets applied around the whole layout.
  final EdgeInsetsGeometry padding;

  /// Rendered between the two areas. A widget rather than an inset so a
  /// screen can put a rule or a spacer there without this layout caring.
  final Widget gap;

  /// An optional panel beside the workspace, shown only on a desktop-class
  /// window.
  ///
  /// Above [AppBreakpoints.expandedMinWidth] there is horizontal space a single
  /// column cannot use: the workspace gets wider keys and wider cards and
  /// nothing else. A panel turns that slack into the thing a productivity
  /// layout is actually for — this tool's own recent results, one tap from the
  /// workspace that produced them.
  ///
  /// It is a slot rather than a feature because the decision belongs to the
  /// caller. What belongs beside a calculator is not what belongs beside a
  /// matrix workspace, and a layout that invented a history list itself would
  /// be wrong for half its callers.
  ///
  /// Below the threshold the panel is not rendered at all rather than
  /// collapsed: on a phone that width is worth more to the workspace itself,
  /// and a header promising a panel that is not there is worse than no header.
  final Widget? sidePanel;

  /// Width the [sidePanel] occupies once shown.
  final double sidePanelWidth;

  const ResponsiveWorkspaceLayout({
    super.key,
    required this.displayArea,
    required this.controls,
    this.pinControls = false,
    this.displayFlex = 55,
    this.controlsFlex = 45,
    this.controlsMinHeight = 350,
    this.padding = EdgeInsets.zero,
    this.gap = const SizedBox.shrink(),
    this.sidePanel,
    this.sidePanelWidth = 320,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A section hosted in an IndexedStack builds on the first frame, while
        // Android insets are still settling and the window can measure zero.
        // Every arithmetic below assumes a real extent, so render nothing rather
        // than divide by one that is not there. Hoisted here so a screen cannot
        // forget it — each caller had been growing its own copy.
        if (!constraints.hasBoundedHeight || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        // Only where there is genuinely room: the panel comes out of the width
        // the workspace would otherwise have used, so a window too narrow to
        // spare it is not a window worth spending it on.
        final showPanel =
            sidePanel != null &&
            constraints.isExpandedWidth &&
            constraints.maxWidth - sidePanelWidth >=
                AppBreakpoints.compactMaxWidth;

        final workspace = _buildWorkspace(constraints);
        if (!showPanel) return workspace;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: workspace),
            SizedBox(width: sidePanelWidth, child: sidePanel),
          ],
        );
      },
    );
  }

  /// The display area and the controls, arranged by [pinControls] and by how
  /// much height there is.
  Widget _buildWorkspace(BoxConstraints constraints) {
    if (constraints.isShortScreen) {
      // Constrained height: fall back to one scroll so the controls keep a
      // readable size instead of being squeezed by the display area.
      //
      // A fixed box, not a `minHeight` floor: a control area built on `Expanded`
      // — the calculator's keypad — has no height of its own and must be given
      // one. A screen whose controls size to their own content still has to fit
      // inside it, which is what [controlsMinHeight] is for.
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            displayArea,
            gap,
            SafeArea(
              top: false,
              bottom: true,
              child: SizedBox(height: controlsMinHeight, child: controls),
            ),
          ],
        ),
      );
    }

    if (!pinControls) {
      // Everything sizes to its content and scrolls as one surface, so the
      // result sits directly beneath the inputs that produced it.
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            displayArea,
            gap,
            controls,
            // Keeps the last control clear of the system navigation bar
            // without adding a gap when there is no inset to clear.
            const SafeArea(top: false, bottom: true, child: SizedBox.shrink()),
          ],
        ),
      );
    }

    // Pinned: the display area shrinks to its content up to its share, and the
    // controls expand into everything left over.
    return Padding(
      padding: padding,
      child: Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  constraints.maxHeight *
                  (displayFlex / (displayFlex + controlsFlex)),
            ),
            child: displayArea,
          ),
          gap,
          Expanded(child: SafeArea(top: false, bottom: true, child: controls)),
        ],
      ),
    );
  }
}
