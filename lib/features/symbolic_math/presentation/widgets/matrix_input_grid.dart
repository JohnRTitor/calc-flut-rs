import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// A grid of exact-entry cells for typing a matrix.
///
/// Laid out with a plain scrollable box rather than a two-dimensional one: the
/// grid is sized by what the user chose, it is never larger than the viewport by
/// accident, and nesting a pinch-and-pan grid inside a scrolling screen would
/// make the two fight over the same gesture. Rows and columns can be added and
/// removed because a matrix has to be square only sometimes, and the backend
/// says so rather than the UI hiding it.
class MatrixInputGrid extends StatefulWidget {
  final UiStyle uiStyle;

  /// The cells, row-major.
  final List<List<String>> cells;

  /// Invoked with the whole grid whenever it changes.
  final ValueChanged<List<List<String>>> onChanged;

  const MatrixInputGrid({
    super.key,
    required this.uiStyle,
    required this.cells,
    required this.onChanged,
  });

  /// Largest grid offered, in cells.
  ///
  /// Matches the backend's own cap. Offering more would produce a refusal
  /// rather than an answer, so the controls stop here.
  static const int maxCells = 64;

  /// A blank 2x2 grid, which is the smallest useful starting point.
  static List<List<String>> initialCells() => [
    ['1', '0'],
    ['0', '1'],
  ];

  @override
  State<MatrixInputGrid> createState() => _MatrixInputGridState();
}

class _MatrixInputGridState extends State<MatrixInputGrid> {
  /// Controllers per cell, so the caret and the text stay put while typing.
  final Map<String, TextEditingController> _controllers = {};

  String _key(int row, int column) => '$row:$column';

  TextEditingController _controllerFor(int row, int column, String value) {
    return _controllers.putIfAbsent(
      _key(row, column),
      () => TextEditingController(text: value),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(MatrixInputGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  /// Brings the controllers in line with the cells, dropping any for cells that
  /// no longer exist.
  ///
  /// A cell is only written when its text has actually gone stale, so the
  /// rebuild that follows a keystroke leaves the field alone. That keeps the
  /// caret where it is, and still lets a grid replaced from elsewhere — a
  /// history restore, say — be adopted.
  void _syncControllers() {
    final wanted = <String>{};
    for (var r = 0; r < widget.cells.length; r++) {
      for (var c = 0; c < widget.cells[r].length; c++) {
        wanted.add(_key(r, c));
        final controller = _controllerFor(r, c, widget.cells[r][c]);
        if (controller.text != widget.cells[r][c]) {
          controller.text = widget.cells[r][c];
        }
      }
    }
    for (final key in _controllers.keys.toList()) {
      if (!wanted.contains(key)) {
        _controllers.remove(key)!.dispose();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<List<String>> _with(int row, int column, String value) {
    final next = [
      for (var r = 0; r < widget.cells.length; r++) [...widget.cells[r]],
    ];
    next[row][column] = value;
    return next;
  }

  void _addRow() {
    final width = widget.cells.isEmpty ? 2 : widget.cells.first.length;
    if ((widget.cells.length + 1) * width > MatrixInputGrid.maxCells) return;
    setState(
      () => widget.onChanged([...widget.cells, List.filled(width, '0')]),
    );
  }

  void _addColumn() {
    final width = widget.cells.isEmpty ? 2 : widget.cells.first.length;
    if (widget.cells.length * (width + 1) > MatrixInputGrid.maxCells) return;
    setState(
      () => widget.onChanged([
        for (final row in widget.cells) [...row, '0'],
      ]),
    );
  }

  void _removeRow(int index) {
    if (widget.cells.length <= 1) return;
    setState(
      () => widget.onChanged([
        for (var r = 0; r < widget.cells.length; r++)
          if (r != index) [...widget.cells[r]],
      ]),
    );
  }

  void _removeColumn(int index) {
    final width = widget.cells.isEmpty ? 2 : widget.cells.first.length;
    if (width <= 1) return;
    setState(
      () => widget.onChanged([
        for (final row in widget.cells)
          [
            for (var c = 0; c < width; c++)
              if (c != index) row[c],
          ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rows = widget.cells.length;
    final columns = rows == 0 ? 0 : widget.cells.first.length;
    final atMax = rows * columns >= MatrixInputGrid.maxCells;

    return SharedSurface(
      uiStyle: widget.uiStyle,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var r = 0; r < rows; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        for (var c = 0; c < columns; c++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CellField(
                              controller: _controllerFor(
                                r,
                                c,
                                widget.cells[r][c],
                              ),
                              onChanged: (value) =>
                                  widget.onChanged(_with(r, c, value)),
                            ),
                          ),
                        SizedBox(
                          width: AppChip.minimumTouchTarget,
                          height: AppChip.minimumTouchTarget,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.remove, size: 18),
                            tooltip: 'Remove row ${r + 1}',
                            onPressed: rows <= 1 ? null : () => _removeRow(r),
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: atMax ? null : _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Row'),
              ),
              TextButton.icon(
                onPressed: atMax ? null : _addColumn,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Column'),
              ),
              if (columns > 0)
                TextButton.icon(
                  onPressed: columns <= 1 ? null : () => _removeColumn(0),
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('First column'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One cell of the grid.
class _CellField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _CellField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 88,
      height: 56,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        // A matrix entry is a number or a fraction, so the keyboard is the
        // numeric one with a sign. Fractions are still typeable on it.
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [
          // No restriction on length: an entry may be a very large integer, and
          // refusing digits here would be the UI disagreeing with the maths.
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
