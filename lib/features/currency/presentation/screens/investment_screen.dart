import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/currency/presentation/providers/investment_provider.dart';
import 'package:calc_flut_rs/features/currency/presentation/widgets/utilities_keypad.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/app_tab_bar.dart';
import 'package:calc_flut_rs/shared/widgets/screenshot_share_wrapper.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_keypad_layout.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class InvestmentScreen extends ConsumerStatefulWidget {
  const InvestmentScreen({super.key});

  @override
  ConsumerState<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends ConsumerState<InvestmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScreenshotShareWrapperState> _screenshotKey =
      GlobalKey<ScreenshotShareWrapperState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final mode = _tabController.index == 0
            ? InvestmentMode.oneTime
            : InvestmentMode.sip;
        ref.read(investmentProvider.notifier).setMode(mode);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(investmentProvider);
    final notifier = ref.read(investmentProvider.notifier);
    final uiStyle = ref.watch(uiStyleProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final result = state.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment'),
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
                  subject: 'Investment Calculation',
                  text:
                      'Expected Returns: ${_currencyFormat.format(result.futureValue)}',
                );
              },
              tooltip: 'Share result',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildPillSwitcher(uiStyle),
          ),
        ),
      ),
      body: ResponsiveKeypadLayout(
        displayFlex: 60,
        keypadFlex: 40,
        keypadMinHeight: 350,
        displayArea: ScreenshotShareWrapper(
          key: _screenshotKey,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBarView(
              controller: _tabController,
              children: [
                // One-Time Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildResultChartArea(
                        context,
                        result,
                        uiStyle,
                        colorScheme,
                        textTheme,
                      ),
                      const SizedBox(height: 24),
                      _buildInputCard(
                        context: context,
                        label: 'Total Investment',
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
                        label: 'Expected Return Rate (p.a)',
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
                      _buildInputCard(
                        context: context,
                        label: 'Time Period',
                        value: state.yearsStr.isEmpty ? '0' : state.yearsStr,
                        symbol: 'Yr',
                        inputId: 'years',
                        isActive: state.activeInput == 'years',
                        onTap: () => notifier.setActiveInput('years'),
                        uiStyle: uiStyle,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),

                // SIP Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildResultChartArea(
                        context,
                        result,
                        uiStyle,
                        colorScheme,
                        textTheme,
                      ),
                      const SizedBox(height: 24),
                      _buildInputCard(
                        context: context,
                        label: 'Monthly Investment',
                        value: state.monthlyContributionStr.isEmpty
                            ? '0'
                            : state.monthlyContributionStr,
                        symbol: '\$',
                        inputId: 'monthlyContribution',
                        isActive: state.activeInput == 'monthlyContribution',
                        onTap: () =>
                            notifier.setActiveInput('monthlyContribution'),
                        uiStyle: uiStyle,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _buildInputCard(
                        context: context,
                        label: 'Expected Return Rate (p.a)',
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
                      _buildInputCard(
                        context: context,
                        label: 'Time Period',
                        value: state.yearsStr.isEmpty ? '0' : state.yearsStr,
                        symbol: 'Yr',
                        inputId: 'years',
                        isActive: state.activeInput == 'years',
                        onTap: () => notifier.setActiveInput('years'),
                        uiStyle: uiStyle,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        keypad: UtilitiesKeypad(onKeyPressed: notifier.onKeyPressed),
      ),
    );
  }

  Widget _buildPillSwitcher(UiStyle uiStyle) {
    return AppTabBar(
      controller: _tabController,
      uiStyle: uiStyle,
      tabs: const [
        Tab(child: Tooltip(message: 'Lump sum investment', child: Text('One-Time'))),
        Tab(child: Tooltip(message: 'Systematic Investment Plan', child: Text('SIP'))),
      ],
    );
  }

  Widget _buildResultChartArea(
    BuildContext context,
    dynamic result,
    UiStyle uiStyle,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final bool hasData = result.totalInvestment > 0 || result.totalInterest > 0;

    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.primary,
      materialColor: themeExt.resultCard,
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Value',
                      style: textTheme.bodyMedium?.copyWith(
                        color: themeExt.resultText.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      _currencyFormat.format(result.futureValue),
                      style: textTheme.headlineSmall?.copyWith(
                        color: themeExt.resultText,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Est. Returns',
                              style: textTheme.bodySmall?.copyWith(
                                color: themeExt.resultText.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            Text(
                              _currencyFormat.format(result.totalInterest),
                              style: textTheme.titleSmall?.copyWith(
                                color: themeExt.resultText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invested Amount',
                              style: textTheme.bodySmall?.copyWith(
                                color: themeExt.resultText.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            Text(
                              _currencyFormat.format(result.totalInvestment),
                              style: textTheme.titleSmall?.copyWith(
                                color: themeExt.resultText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                height: 120,
                child: hasData
                    ? PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          startDegreeOffset: -90,
                          sections: [
                            PieChartSectionData(
                              color: colorScheme.primary,
                              value: result.totalInterest,
                              title: '',
                              radius: 20,
                            ),
                            PieChartSectionData(
                              color: colorScheme.tertiary,
                              value: result.totalInvestment,
                              title: '',
                              radius: 20,
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          '0%',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
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
              if (symbol == '%' || symbol == 'Yr')
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    symbol,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
