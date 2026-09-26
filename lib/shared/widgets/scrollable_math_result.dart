import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/math_expression_text.dart';

/// How a result that is too wide for its card is presented.
///
/// Ordered best-first. The component walks this ladder and stops at the first
/// rung that fits, so a result only degrades when it genuinely has to.
enum ResultOverflowStrategy {
  /// The result is no wider than its card. Rendered exactly as written.
  fits,

  /// A single line at a smaller step of the display type scale. Nothing is
  /// hidden and nothing scrolls.
  shrunk,

  /// Wrapped onto a second line at the smallest step. The card grows to fit.
  wrapped,

  /// Too long to wrap within [ScrollableMathResult.maxLines]. Scrollable
  /// horizontally, starting at the beginning, with an edge fade marking the
  /// content that is off screen.
  scrollable,
}

/// Renders a mathematical result so that the reader can always tell whether they
/// are looking at the whole answer.
///
/// The failure this exists to prevent: a result wider than its card used to be
/// placed in a horizontally-scrolling view pre-scrolled to its **end**, so the
/// opening of a factored expression — its `(x + 1)*` — sat off screen with no
/// scrollbar and no fade. The visible text read as a complete answer while
/// being a fragment, which for an app whose whole claim is exact, unapproximated
/// results is a correctness problem and not merely a cosmetic one.
///
/// The ladder is deliberate:
///
/// 1. **fits** — render as-is, no wrapper, no overhead.
/// 2. **shrunk** — step down the display type scale. A longer answer becomes a
///    slightly smaller answer, which is the least lossy option available.
/// 3. **wrapped** — break onto a second line. The card grows. Preferred over
///    scrolling because a wrapped answer is still wholly visible.
/// 4. **scrollable** — genuinely pathological input only. Scrolls, but always
///    anchored at the **start**, so any truncation clips the tail (which reads
///    as "there is more") rather than the head (which reads as a broken
///    layout), and the [ResultOverflowFade] marks the off-screen edge.
class ScrollableMathResult extends StatefulWidget {
  /// The expression to render, as produced by the symbolic backend.
  final String expression;

  /// The style the result would be rendered at if it fitted.
  final TextStyle? style;

  /// Horizontal alignment when the result wraps onto more than one line.
  final TextAlign textAlign;

  /// Whether the text may break onto a second line before falling back to
  /// scrolling. Set `false` where the host pins the result to a fixed height
  /// that a second line would overflow — the calculator's display panel, for
  /// instance, which must not resize as the user types.
  final bool allowWrap;

  /// Most lines [allowWrap] may produce before the result becomes scrollable.
  final int maxLines;

  /// Fraction multipliers applied to [style]'s font size, largest first.
  static const List<double> shrinkSteps = <double>[1.0, 0.82, 0.68];

  const ScrollableMathResult({
    super.key,
    required this.expression,
    required this.uiStyle,
    this.style,
    this.textAlign = TextAlign.left,
    this.allowWrap = true,
    this.maxLines = 2,
  });

  /// The active visual style. Every component in this app takes one so that a
  /// caller cannot accidentally render a result that only looks right in one
  /// theme.
  final UiStyle uiStyle;

  @override
  State<ScrollableMathResult> createState() => _ScrollableMathResultState();
}

class _ScrollableMathResultState extends State<ScrollableMathResult> {
  final ScrollController _controller = ScrollController();

  /// Whether the chosen step still overflows and the result is scrollable.
  bool _isScrollable = false;

  /// Horizontal scroll offset, cached so the fade can follow it.
  double _offset = 0;

  /// How far the view can scroll, cached for the same reason.
  ///
  /// Starts at infinity rather than zero so that, before the scroll position
  /// has reported itself, the view reads as "not at the end" and therefore
  /// fades the trailing edge. A zero default would claim the opposite — the
  /// content is off to the right, so the first frame would show no fade at all,
  /// which is exactly the unmarked truncation this component exists to remove.
  double _maxScrollExtent = double.infinity;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  /// A new answer starts at its beginning.
  ///
  /// Without this, a result that is still scrollable after the user has scrolled
  /// into the middle of it would inherit that offset — and inheriting the *end*
  /// is precisely the defect this component exists to remove. The reset is
  /// deferred to after the frame because doing it here would run before the new
  /// content has been laid out, and calling it synchronously from `build` while
  /// the old scroll view still has clients notifies the listener mid-build.
  @override
  void didUpdateWidget(ScrollableMathResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) _resetScrollAfterFrame();
  }

  void _resetScrollAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (_controller.offset != 0) _controller.jumpTo(0);
      _syncFadeFromPosition();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_controller.hasClients) return;
    final offset = _controller.offset;
    final maxScrollExtent = _controller.position.maxScrollExtent;
    if (offset == _offset && maxScrollExtent == _maxScrollExtent) return;
    setState(() {
      _offset = offset;
      _maxScrollExtent = maxScrollExtent;
    });
  }

  /// Brings the cached fade state back in line with the scroll position,
  /// without assuming a rebuild has already happened for it.
  void _syncFadeFromPosition() {
    if (!mounted || !_controller.hasClients) return;
    final offset = _controller.offset;
    final maxScrollExtent = _controller.position.maxScrollExtent;
    if (offset == _offset && maxScrollExtent == _maxScrollExtent) return;
    setState(() {
      _offset = offset;
      _maxScrollExtent = maxScrollExtent;
    });
  }

  /// How a result at [fontSize] lays out in [width] logical pixels.
  ///
  /// Returns the strategy that rung of the ladder settles on, plus the font
  /// size to render at.
  ({ResultOverflowStrategy strategy, double? fontSize}) _resolve({
    required String text,
    required double availableWidth,
    required double baseFontSize,
    required TextStyle baseStyle,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    if (availableWidth <= 0 || !availableWidth.isFinite) {
      // A non-positive or non-finite extent means the window has not been
      // measured yet. Render nothing rather than divide by it; the shell
      // builds sections inside an IndexedStack, so this is reachable.
      return (strategy: ResultOverflowStrategy.fits, fontSize: null);
    }

    final smallest = baseFontSize * ScrollableMathResult.shrinkSteps.last;

    // Rungs 1 and 2: shrink until a single line fits.
    for (final step in ScrollableMathResult.shrinkSteps) {
      final fontSize = baseFontSize * step;
      final measured = _measure(
        text: text,
        style: baseStyle.copyWith(fontSize: fontSize),
        textScaler: textScaler,
        textDirection: textDirection,
        maxWidth: double.infinity,
      );
      if (measured.width <= availableWidth) {
        return (
          strategy: step == ScrollableMathResult.shrinkSteps.first
              ? ResultOverflowStrategy.fits
              : ResultOverflowStrategy.shrunk,
          fontSize: fontSize,
        );
      }
    }

    // Rung 3: wrap at the smallest step, but only as many lines as allowed.
    if (widget.allowWrap) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(fontSize: smallest),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.left,
        textScaler: textScaler,
      )..layout(maxWidth: availableWidth);

      // The painter's own preferred line height, rather than a nominal
      // multiple of the font size: the real value depends on the font and on
      // the theme's text height, and a guess that runs small lets a result
      // through as "fits in two lines" that actually needs four — silently
      // clipped, which is the failure this ladder exists to prevent.
      if (painter.preferredLineHeight * widget.maxLines >= painter.height) {
        painter.dispose();
        return (strategy: ResultOverflowStrategy.wrapped, fontSize: smallest);
      }
      painter.dispose();
    }

    // Rung 4: genuinely too long. Scroll, anchored at the start.
    return (strategy: ResultOverflowStrategy.scrollable, fontSize: smallest);
  }

  /// Lays the text out and reports how much room it actually needs.
  ///
  /// Both numbers matter, for different rungs: the single-line check needs the
  /// intrinsic [width], while the wrap check needs the [height] it settles at
  /// inside a bounded width.
  ({double width, double height}) _measure({
    required String text,
    required TextStyle style,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textAlign: TextAlign.left,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    return (width: painter.width, height: painter.height);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = formatMathForDisplay(widget.expression);
    final baseStyle =
        widget.style ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle();
    final baseFontSize = baseStyle.fontSize ?? 16.0;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = _resolve(
          text: formatted,
          availableWidth: constraints.maxWidth,
          baseFontSize: baseFontSize,
          baseStyle: baseStyle,
          textScaler: textScaler,
          textDirection: textDirection,
        );

        final fontSize = resolved.fontSize;
        final textStyle = fontSize == null
            ? baseStyle
            : baseStyle.copyWith(fontSize: fontSize);
        final isScrollable =
            resolved.strategy == ResultOverflowStrategy.scrollable;

        // Becoming scrollable means the view is being newly created around
        // fresh content, so it must open at the start. The reset is deferred:
        // jumping the controller from here notifies the scroll listener while
        // this build is still running, which is a setState-during-build.
        if (_isScrollable != isScrollable) {
          _isScrollable = isScrollable;
          if (isScrollable) _resetScrollAfterFrame();
        }

        final text = Text(
          formatted,
          style: textStyle,
          textAlign: widget.textAlign,
          maxLines: isScrollable
              ? 1
              : (resolved.strategy == ResultOverflowStrategy.wrapped
                    ? widget.maxLines
                    : 1),
          softWrap: !isScrollable,
          overflow: isScrollable ? TextOverflow.clip : TextOverflow.ellipsis,
        );

        if (!isScrollable) return text;

        return ResultOverflowFade(
          isScrolledToStart: _offset <= 0.5,
          isScrolledToEnd: _offset >= _maxScrollExtent - 0.5,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: text,
          ),
        );
      },
    );
  }
}

/// Marks whichever edge of a scrollable result has content off screen.
///
/// A [ShaderMask] in `dstIn` mode, so the fade is the content becoming
/// transparent rather than a scrim painted over it: it works identically over
/// a Material container and over the translucent Liquid Glass gradient, and
/// needs no colour of its own to be right in both themes.
///
/// When the result does not scroll, the mask is a no-op pass-through — callers
/// wrap unconditionally rather than branching.
class ResultOverflowFade extends StatelessWidget {
  /// Whether the view is currently showing the beginning of the content.
  final bool isScrolledToStart;

  /// Whether the view is currently showing the end of the content.
  final bool isScrolledToEnd;

  /// Width of the gradient ramp at each edge, in logical pixels.
  static const double fadeWidth = 20.0;

  final Widget child;

  const ResultOverflowFade({
    super.key,
    required this.isScrolledToStart,
    required this.isScrolledToEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) return child;

        final fraction = (fadeWidth / width).clamp(0.0, 0.5);
        final fadeInStart = isScrolledToStart ? 0.0 : fraction;
        final fadeInEnd = isScrolledToEnd ? 0.0 : fraction;

        // Nothing off screen on either side: skip the mask entirely so a
        // result that happens to have been scrolled back needs no compositing.
        if (fadeInStart == 0.0 && fadeInEnd == 0.0) return child;

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: <double>[0.0, fadeInStart, 1 - fadeInEnd, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}
