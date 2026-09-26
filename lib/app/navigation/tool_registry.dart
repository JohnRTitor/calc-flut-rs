import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/generated/rust/bridge/converter.dart';
import 'package:calc_flut_rs/app/navigation/route_transitions.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/calculator_screen.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/modular_arithmetic_workspace_screen.dart';
import 'package:calc_flut_rs/features/converter/presentation/providers/converter_provider.dart';
import 'package:calc_flut_rs/features/converter/presentation/screens/converter_detail_screen.dart';
import 'package:calc_flut_rs/features/converter/presentation/screens/date_calculator_screen.dart';
import 'package:calc_flut_rs/features/converter/presentation/screens/converter_home_screen.dart';
import 'package:calc_flut_rs/features/currency/presentation/screens/currency_home_screen.dart';
import 'package:calc_flut_rs/features/currency/presentation/screens/investment_screen.dart';
import 'package:calc_flut_rs/features/currency/presentation/screens/loan_calculator_screen.dart';
import 'package:calc_flut_rs/features/history/presentation/screens/history_screen.dart';
import 'package:calc_flut_rs/features/settings/presentation/screens/settings_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/algebra_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/calculus_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/equation_solver_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/matrix_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/number_theory_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/symbolic_math_home_screen.dart';
import 'package:calc_flut_rs/shared/widgets/app_hub_grid.dart';
import 'package:calc_flut_rs/shared/widgets/app_notice.dart';

/// Signature for the optional state preparation that must run before a tool's
/// screen is pushed (e.g. seeding the converter provider with a category).
typedef AppToolPreparation = void Function(BuildContext context, WidgetRef ref);

/// A single, addressable tool inside the application.
///
/// A tool is the unit shown by hub grids, the navigation drawer/rail sub-lists,
/// and the tool search. Registering a tool here makes it reachable everywhere
/// without any further wiring.
@immutable
class AppTool {
  /// Stable identifier, also used as the persistence and search key.
  final String id;

  /// Human readable name. Must match the pushed screen's `AppBar.title`.
  final String label;

  /// Icon shown in hub grids, the drawer/rail and search results.
  final IconData icon;

  /// When `false` the tool is still listed but reports that it is not
  /// implemented yet instead of opening a screen.
  final bool isAvailable;

  /// Builds the screen pushed for this tool.
  final WidgetBuilder builder;

  /// Optional hook invoked with the calling context before [builder] is pushed.
  final AppToolPreparation? onPrepare;

  const AppTool({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.isAvailable = true,
    this.onPrepare,
  });

  /// Opens the tool on the closest [Navigator].
  ///
  /// Unavailable tools surface a transient notice instead of pushing a screen,
  /// so every caller (hub grids, search, drawer) behaves identically.
  Future<void> open(BuildContext context, WidgetRef ref) async {
    if (!isAvailable) {
      showAppNotice(context, '$label Coming Soon');
      return;
    }

    onPrepare?.call(context, ref);
    await Navigator.of(
      context,
    ).push(FadePageRoute(page: Builder(builder: builder)));
  }
}

/// A top level destination in the app shell (drawer entry, rail destination and
/// [IndexedStack] host).
@immutable
class AppSection {
  /// Stable identifier used for selection and persistence.
  final String id;

  /// Human readable name, shown as the section `AppBar.title`.
  final String label;

  /// Icon shown in the drawer, the rail and the search results.
  final IconData icon;

  /// The section's root widget, hosted by the shell.
  final WidgetBuilder builder;

  /// The tools this section owns. Empty for sections that are a single screen.
  final List<AppTool> tools;

  const AppSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.tools = const [],
  });
}

/// Finds a section by its [AppSection.id], or `null` when unknown.
AppSection? appSectionById(String id) {
  for (final section in appSections) {
    if (section.id == id) {
      return section;
    }
  }
  return null;
}

/// Maps registry tools onto the shared hub grid item model.
///
/// Routing every card through [AppTool.open] guarantees a hub grid card and a
/// search result can never drift apart in behaviour.
List<AppHubGridItem> appHubItemsForTools(
  BuildContext context,
  WidgetRef ref,
  Iterable<AppTool> tools,
) {
  return tools
      .map(
        (tool) => AppHubGridItem(
          id: tool.id,
          label: tool.label,
          icon: tool.icon,
          onTap: () => tool.open(context, ref),
        ),
      )
      .toList();
}

IconData _converterIcon(String iconName) {
  switch (iconName) {
    case 'straighten':
      return Icons.straighten;
    case 'texture':
      return Icons.texture;
    case 'scale':
      return Icons.scale;
    case 'water_drop':
      return Icons.water_drop;
    case 'thermostat':
      return Icons.thermostat;
    case 'speed':
      return Icons.speed;
    case 'schedule':
      return Icons.schedule;
    case 'storage':
      return Icons.storage;
    case 'pin':
      return Icons.pin;
    default:
      return Icons.category;
  }
}

List<AppTool> _buildConverterTools() {
  return [
    AppTool(
      id: 'date',
      label: 'Date Difference',
      icon: Icons.calendar_month,
      builder: (_) => const DateCalculatorScreen(),
    ),
    AppTool(
      id: 'bmi',
      label: 'BMI',
      icon: Icons.monitor_weight,
      builder: (_) => const ConverterDetailScreen(),
      onPrepare: (context, ref) {
        ref
            .read(converterProvider.notifier)
            .setCategory(_syntheticConverterCategory('bmi', 'BMI', false));
      },
    ),
    ...getConverterCategories().map(
      (category) => AppTool(
        id: category.id,
        label: category.name,
        icon: _converterIcon(category.iconName),
        builder: (_) => const ConverterDetailScreen(),
        onPrepare: (context, ref) {
          ref.read(converterProvider.notifier).setCategory(category);
        },
      ),
    ),
  ];
}

List<AppTool> _buildCurrencyTools() {
  return [
    AppTool(
      id: 'currency',
      label: 'Currency',
      icon: Icons.currency_exchange,
      builder: (_) => const ConverterDetailScreen(),
      onPrepare: (context, ref) {
        ref
            .read(converterProvider.notifier)
            .setCategory(
              _syntheticConverterCategory('currency', 'Currency', true),
            );
      },
    ),
    const AppTool(
      id: 'loan',
      label: 'Loan / EMI',
      icon: Icons.real_estate_agent,
      builder: _buildLoanScreen,
    ),
    const AppTool(
      id: 'investment',
      label: 'Investment',
      icon: Icons.trending_up,
      builder: _buildInvestmentScreen,
    ),
    const AppTool(
      id: 'discount',
      label: 'Discount',
      icon: Icons.local_offer,
      isAvailable: false,
      builder: _buildEmptyToolScreen,
    ),
    const AppTool(
      id: 'gst',
      label: 'GST',
      icon: Icons.receipt_long,
      isAvailable: false,
      builder: _buildEmptyToolScreen,
    ),
  ];
}

List<AppTool> _buildSymbolicMathTools() {
  return [
    const AppTool(
      id: 'modular_arithmetic',
      label: 'Modular Arithmetic',
      icon: Icons.architecture,
      builder: _buildModularArithmeticScreen,
    ),
    const AppTool(
      id: 'algebra',
      label: 'Algebra',
      icon: Icons.functions,
      builder: _buildAlgebraScreen,
    ),
    const AppTool(
      id: 'equation_solver',
      label: 'Equation Solver',
      icon: Icons.balance,
      builder: _buildEquationSolverScreen,
    ),
    const AppTool(
      id: 'calculus',
      label: 'Calculus',
      icon: Icons.show_chart,
      builder: _buildCalculusScreen,
    ),
    const AppTool(
      id: 'matrices',
      label: 'Matrices',
      icon: Icons.grid_on,
      builder: _buildMatrixScreen,
    ),
    const AppTool(
      id: 'number_theory',
      label: 'Number Theory',
      icon: Icons.tag,
      builder: _buildNumberTheoryScreen,
    ),
  ];
}

FfiConverterCategory _syntheticConverterCategory(
  String id,
  String name,
  bool showSwapUnitsToggler,
) {
  return FfiConverterCategory(
    id: id,
    name: name,
    iconName: '',
    units: [],
    showSwapUnitsToggler: showSwapUnitsToggler,
    showResultSection: true,
  );
}

Widget _buildLoanScreen(BuildContext context) => const LoanCalculatorScreen();

Widget _buildInvestmentScreen(BuildContext context) => const InvestmentScreen();

Widget _buildModularArithmeticScreen(BuildContext context) =>
    const ModularArithmeticWorkspaceScreen();

Widget _buildAlgebraScreen(BuildContext context) => const AlgebraScreen();

Widget _buildCalculusScreen(BuildContext context) => const CalculusScreen();

Widget _buildEquationSolverScreen(BuildContext context) =>
    const EquationSolverScreen();

Widget _buildMatrixScreen(BuildContext context) => const MatrixScreen();

Widget _buildNumberTheoryScreen(BuildContext context) =>
    const NumberTheoryScreen();

Widget _buildEmptyToolScreen(BuildContext context) => const SizedBox.shrink();

/// Builds the complete navigation registry.
///
/// The converter section is derived from the Rust converter catalogue, so this
/// must stay a function rather than a `const` list.
List<AppSection> buildAppSections() {
  return [
    AppSection(
      id: 'calculator',
      label: 'Calculator',
      icon: Icons.calculate_outlined,
      builder: (_) => const CalculatorScreen(),
    ),
    AppSection(
      id: 'converter',
      label: 'Converter',
      icon: Icons.swap_horiz_outlined,
      builder: (_) => const ConverterHomeScreen(),
      tools: _buildConverterTools(),
    ),
    AppSection(
      id: 'currency',
      label: 'Currency & Finance',
      icon: Icons.attach_money_outlined,
      builder: (_) => const CurrencyHomeScreen(),
      tools: _buildCurrencyTools(),
    ),
    AppSection(
      id: 'symbolic_math',
      label: 'Symbolic Math',
      icon: Icons.functions,
      builder: (_) => const SymbolicMathHomeScreen(),
      tools: _buildSymbolicMathTools(),
    ),
    AppSection(
      id: 'history',
      label: 'History',
      icon: Icons.history,
      // Hosted inside the shell, which already shows the section title.
      builder: (_) => const HistoryScreen(embedded: true),
    ),
    const AppSection(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      // Hosted inside the shell, which already shows the section title.
      builder: _buildSettingsSection,
    ),
  ];
}

Widget _buildSettingsSection(BuildContext context) =>
    const SettingsScreen(embedded: true);

/// The single source of truth for every section and tool in the application.
///
/// The navigation drawer, the navigation rail, every hub grid and the tool
/// search all read from this list — adding a tool is a one-line edit here.
final List<AppSection> appSections = buildAppSections();
