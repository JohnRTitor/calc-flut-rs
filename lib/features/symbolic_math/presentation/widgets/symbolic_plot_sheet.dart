import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_plot_chart.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// Samples `expression` for plotting.
///
/// A bottom sheet rather than a new screen: a chart needs room, and the app's
/// convention is that anything reachable from a tool is a sheet or dialog on top
/// of it rather than a new destination.
Future<rust_symbolic.PlotData?> showSymbolicPlotSheet({
  required BuildContext context,
  required UiStyle uiStyle,
  required String expression,
  required String variable,
}) {
  return showModalBottomSheet<rust_symbolic.PlotData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SymbolicPlotSheet(
      uiStyle: uiStyle,
      expression: expression,
      variable: variable,
    ),
  );
}

class _SymbolicPlotSheet extends ConsumerStatefulWidget {
  final UiStyle uiStyle;
  final String expression;
  final String variable;

  const _SymbolicPlotSheet({
    required this.uiStyle,
    required this.expression,
    required this.variable,
  });

  @override
  ConsumerState<_SymbolicPlotSheet> createState() => _SymbolicPlotSheetState();
}

class _SymbolicPlotSheetState extends ConsumerState<_SymbolicPlotSheet> {
  late Future<rust_symbolic.PlotData> _future;

  @override
  void initState() {
    super.initState();
    _future = _sample();
  }

  Future<rust_symbolic.PlotData> _sample() {
    return rust_symbolic.symbolicPlot(
      expression: widget.expression,
      variable: widget.variable,
    );
  }

  void _resample() {
    setState(() => _future = _sample());
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SharedSurface(
        uiStyle: uiStyle,
        glassRole: GlassSurfaceRole.panel,
        frosted: true,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'y = ${widget.expression}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Resample',
                      onPressed: _resample,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sampled numerically. Holes in the curve are places the '
                  'function is not defined.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                // A fixed height rather than unbounded: the chart must not
                // fight the sheet's drag-to-dismiss for the gesture.
                SizedBox(
                  height: 280,
                  child: FutureBuilder<rust_symbolic.PlotData>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _PlotFailure(
                          message: _messageFor(snapshot.error!),
                        );
                      }
                      final data = snapshot.data;
                      if (data == null) {
                        return _PlotFailure(message: 'Could not plot that');
                      }
                      return SymbolicPlotChart(data: data);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Turns the bridge's typed error into something showable.
  ///
  /// A typed error carries its own message, so there is nothing to strip here —
  /// the fallback exists only for a failure raised outside the call.
  String _messageFor(Object error) {
    if (error is rust_symbolic.SymbolicErrorInfo) return error.message;
    return 'Could not plot that expression';
  }
}

class _PlotFailure extends StatelessWidget {
  final String message;

  const _PlotFailure({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
