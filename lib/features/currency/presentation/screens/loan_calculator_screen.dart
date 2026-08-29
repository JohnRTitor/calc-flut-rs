import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/currency/presentation/providers/loan_calculator_provider.dart';
import 'package:calc_flut_rs/features/currency/presentation/widgets/utilities_keypad.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/screenshot_share_wrapper.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_keypad_layout.dart';
import 'package:intl/intl.dart';

class LoanCalculatorScreen extends ConsumerStatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  ConsumerState<LoanCalculatorScreen> createState() =>
      _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends ConsumerState<LoanCalculatorScreen> {
  final GlobalKey<ScreenshotShareWrapperState> _screenshotKey =
      GlobalKey<ScreenshotShareWrapperState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanCalculatorProvider);
    final notifier = ref.read(loanCalculatorProvider.notifier);
    final uiStyle = ref.watch(uiStyleProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;

    final cardTextColor = themeExt.resultText;

    final result = state.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan / EMI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.reset(),
            tooltip: 'Reset',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () {
                _screenshotKey.currentState?.captureAndShare(
                  subject: 'Loan / EMI Calculation',
                  text:
                      'Monthly EMI: ${_currencyFormat.format(result.monthlyEmi)}\nTotal Interest: ${_currencyFormat.format(result.totalInterest)}',
                );
              },
              tooltip: 'Share result',
            ),
          ),
        ],
      ),
      body: ResponsiveKeypadLayout(
        displayFlex: 55,
        keypadFlex: 45,
        keypadMinHeight: 350,
        displayArea: ScreenshotShareWrapper(
          key: _screenshotKey,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Result Card
                  SharedSurface(
                    uiStyle: uiStyle,
                    glassRole: GlassSurfaceRole.primary,
                    materialColor: themeExt.resultCard,
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        Text(
                          'Monthly EMI',
                          style: textTheme.titleMedium?.copyWith(
                            color: cardTextColor.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFormat.format(result.monthlyEmi),
                          style: textTheme.displayMedium?.copyWith(
                            color: cardTextColor,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(
                          color: cardTextColor.withValues(alpha: 0.2),
                          thickness: 1,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                context: context,
                                label: 'Total Interest',
                                value: _currencyFormat.format(
                                  result.totalInterest,
                                ),
                                textTheme: textTheme,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: cardTextColor.withValues(alpha: 0.2),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                context: context,
                                label: 'Total Payment',
                                value: _currencyFormat.format(
                                  result.totalPayment,
                                ),
                                textTheme: textTheme,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Inputs
                  _buildInputCard(
                    context: context,
                    label: 'Principal Amount',
                    value: state.principalStr.isEmpty
                        ? '0'
                        : state.principalStr,
                    symbol: '\$',
                    inputId: 'principal',
                    isActive: state.activeInput == 'principal',
                    onTap: () => notifier.setActiveInput('principal'),
                    uiStyle: uiStyle,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 12),

                  _buildInputCard(
                    context: context,
                    label: 'Interest Rate (Yearly)',
                    value: state.interestRateStr.isEmpty
                        ? '0'
                        : state.interestRateStr,
                    symbol: '%',
                    inputId: 'interestRate',
                    isActive: state.activeInput == 'interestRate',
                    onTap: () => notifier.setActiveInput('interestRate'),
                    uiStyle: uiStyle,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 12),

                  // Tenure Input
                  _buildTenureInputCard(
                    context: context,
                    state: state,
                    notifier: notifier,
                    uiStyle: uiStyle,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ),
        ),
        keypad: UtilitiesKeypad(onKeyPressed: notifier.onKeyPressed),
      ),
    );
  }

  Widget _buildSummaryItem({
    required BuildContext context,
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;
    final textColor = themeExt.resultText;
    return Column(
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard({
    required BuildContext context,
    required String label,
    required String value,
    required String symbol,
    required String inputId,
    required bool isActive,
    required VoidCallback onTap,
    required UiStyle uiStyle,
    required ColorScheme colorScheme,
  }) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      materialColor: themeExt.calculatorCard,
      isInteractive: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          Row(
            children: [
              if (symbol == '\$')
                Text(
                  symbol,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isActive ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (symbol == '%')
                Text(
                  symbol,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTenureInputCard({
    required BuildContext context,
    required LoanCalculatorState state,
    required LoanCalculatorNotifier notifier,
    required UiStyle uiStyle,
    required ColorScheme colorScheme,
  }) {
    final isActive = state.activeInput == 'tenure';

    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      materialColor: themeExt.calculatorCard,
      isInteractive: true,
      onTap: () => notifier.setActiveInput('tenure'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Text(
            'Loan Tenure',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            state.tenureStr.isEmpty ? '0' : state.tenureStr,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isActive ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          // Toggle between Years and Months
          SharedSurface(
            uiStyle: uiStyle,
            glassRole: GlassSurfaceRole.panel,
            padding: const EdgeInsets.all(4),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTenureToggle(
                  context,
                  label: 'Yr',
                  isSelected: state.tenureType == TenureType.years,
                  onTap: () => notifier.setTenureType(TenureType.years),
                  uiStyle: uiStyle,
                  colorScheme: colorScheme,
                ),
                _buildTenureToggle(
                  context,
                  label: 'Mo',
                  isSelected: state.tenureType == TenureType.months,
                  onTap: () => notifier.setTenureType(TenureType.months),
                  uiStyle: uiStyle,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenureToggle(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required UiStyle uiStyle,
    required ColorScheme colorScheme,
  }) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? themeExt.chipBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected
                ? themeExt.chipText
                : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
