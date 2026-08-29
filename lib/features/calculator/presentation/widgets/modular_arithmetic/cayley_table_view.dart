import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/generated/rust/bridge/modular_arithmetic.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';

class CayleyTableView extends StatefulWidget {
  final UiStyle uiStyle;
  final CayleyTable cayleyTable;
  final String identity;
  final List<InversePair> inverses;

  const CayleyTableView({
    super.key,
    required this.uiStyle,
    required this.cayleyTable,
    required this.identity,
    required this.inverses,
  });

  @override
  State<CayleyTableView> createState() => _CayleyTableViewState();
}

class _CayleyTableViewState extends State<CayleyTableView> {
  int? _hoveredRow;
  int? _hoveredCol;
  bool _showInverses = false;
  double _baseCellSize = 60.0;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _baseCellSize = (_baseCellSize + 10).clamp(40.0, 120.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _baseCellSize = (_baseCellSize - 10).clamp(40.0, 120.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _baseCellSize = 60.0;
    });
  }

  void _showFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Cayley Table'),
            actions: [
              IconButton(icon: const Icon(Icons.zoom_out), onPressed: _zoomOut),
              IconButton(icon: const Icon(Icons.zoom_in), onPressed: _zoomIn),
              IconButton(icon: const Icon(Icons.restore), onPressed: _resetZoom),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTableContent(),
          ),
        ),
      ),
    );
  }

  void _handleCellTap(int row, int col, String value) {
    if (row == 0 || col == 0) return;
    
    final rowHeader = widget.cayleyTable.headers[row - 1];
    final colHeader = widget.cayleyTable.headers[col - 1];
    final op = widget.cayleyTable.operation;

    showAppDialog(
      context: context,
      uiStyle: widget.uiStyle,
      title: 'Operation Result',
      icon: Icons.calculate_outlined,
      content: Center(
        child: Text(
          '$rowHeader $op $colHeader = $value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
      primaryButtonText: 'Close',
      onPrimaryButtonPressed: () => Navigator.of(context).pop(),
    );
  }

  bool _isInversePair(String a, String b) {
    if (!_showInverses) return false;
    for (var pair in widget.inverses) {
      if ((pair.element == a && pair.inverse == b) ||
          (pair.element == b && pair.inverse == a)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildTableContent() {
    final rowCount = widget.cayleyTable.rows.length + 1;
    final colCount = widget.cayleyTable.headers.length + 1;
    final theme = Theme.of(context);

    return TableView.builder(
      verticalDetails: ScrollableDetails.vertical(controller: _verticalController),
      horizontalDetails: ScrollableDetails.horizontal(controller: _horizontalController),
      rowCount: rowCount,
      columnCount: colCount,
      pinnedRowCount: 1,
      pinnedColumnCount: 1,
      columnBuilder: (int colIndex) => TableSpan(
        extent: FixedTableSpanExtent(_baseCellSize),
      ),
      rowBuilder: (int rowIndex) => TableSpan(
        extent: FixedTableSpanExtent(_baseCellSize),
      ),
      cellBuilder: (BuildContext context, TableVicinity vicinity) {
        final row = vicinity.row;
        final col = vicinity.column;
        
        bool isTopLeft = row == 0 && col == 0;
        bool isRowHeader = row == 0 && col > 0;
        bool isColHeader = col == 0 && row > 0;
        bool isData = row > 0 && col > 0;

        String cellValue = '';
        if (isTopLeft) {
          cellValue = widget.cayleyTable.operation;
        } else if (isRowHeader) {
          cellValue = widget.cayleyTable.headers[col - 1];
        } else if (isColHeader) {
          cellValue = widget.cayleyTable.headers[row - 1];
        } else if (isData) {
          cellValue = widget.cayleyTable.rows[row - 1][col - 1];
        }

        // Highlighting Logic
        bool isHoveredRow = _hoveredRow == row && isData;
        bool isHoveredCol = _hoveredCol == col && isData;
        bool isHoveredCell = isHoveredRow && isHoveredCol;
        bool isIdentityRow = isData && widget.cayleyTable.headers[row - 1] == widget.identity;
        bool isIdentityCol = isData && widget.cayleyTable.headers[col - 1] == widget.identity;
        
        bool isInverseProduct = false;
        if (isData && _showInverses) {
          final a = widget.cayleyTable.headers[row - 1];
          final b = widget.cayleyTable.headers[col - 1];
          isInverseProduct = _isInversePair(a, b) && cellValue == widget.identity;
        }

        // Determine Cell Color
        Color cellColor = Colors.transparent;
        Color textColor = theme.colorScheme.onSurface;
        FontWeight fontWeight = FontWeight.normal;

        if (isTopLeft || isRowHeader || isColHeader) {
          cellColor = theme.colorScheme.surfaceContainerHigh;
          textColor = theme.colorScheme.primary;
          fontWeight = FontWeight.bold;
        } else {
          if (isHoveredCell) {
            cellColor = theme.colorScheme.primaryContainer;
            textColor = theme.colorScheme.onPrimaryContainer;
            fontWeight = FontWeight.bold;
          } else if (isHoveredRow || isHoveredCol) {
            cellColor = theme.colorScheme.surfaceContainerHighest;
          } else if (isInverseProduct) {
            cellColor = theme.colorScheme.tertiaryContainer;
            textColor = theme.colorScheme.onTertiaryContainer;
            fontWeight = FontWeight.bold;
          } else if (isIdentityRow || isIdentityCol) {
            cellColor = theme.colorScheme.surfaceContainer;
          }
        }

        Widget cellContent = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cellColor,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Text(
            cellValue,
            style: TextStyle(
              color: textColor,
              fontWeight: fontWeight,
              fontFamily: 'monospace',
              fontSize: _baseCellSize * 0.35,
            ),
          ),
        );

        if (isData) {
          cellContent = MouseRegion(
            onEnter: (_) {
              setState(() {
                _hoveredRow = row;
                _hoveredCol = col;
              });
            },
            onExit: (_) {
              setState(() {
                _hoveredRow = null;
                _hoveredCol = null;
              });
            },
            child: GestureDetector(
              onTap: () => _handleCellTap(row, col, cellValue),
              child: cellContent,
            ),
          );
        }

        return TableViewCell(child: cellContent);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  onPressed: _zoomOut,
                  tooltip: 'Zoom Out',
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: _zoomIn,
                  tooltip: 'Zoom In',
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _showFullscreen,
                  tooltip: 'Fullscreen',
                ),
              ],
            ),
            if (widget.inverses.isNotEmpty)
              Row(
                children: [
                  const Text('Show Inverses'),
                  Switch(
                    value: _showInverses,
                    onChanged: (val) {
                      setState(() {
                        _showInverses = val;
                      });
                    },
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 400, // Fixed height for embedded table, can be responsive
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          child: SharedSurface(
            uiStyle: widget.uiStyle,
            glassRole: GlassSurfaceRole.card,
            child: _buildTableContent(),
          ),
        ),
      ],
    );
  }
}
