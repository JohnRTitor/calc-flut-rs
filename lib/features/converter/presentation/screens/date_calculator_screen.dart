import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/converter/presentation/providers/date_calculator_provider.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/screenshot_share_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui' as ui;

class DateCalculatorScreen extends ConsumerStatefulWidget {
  const DateCalculatorScreen({super.key});

  @override
  ConsumerState<DateCalculatorScreen> createState() =>
      _DateCalculatorScreenState();
}

class _DateCalculatorScreenState extends ConsumerState<DateCalculatorScreen> {
  final GlobalKey<ScreenshotShareWrapperState> _screenshotKey =
      GlobalKey<ScreenshotShareWrapperState>();

  Future<void> _selectDate(
    BuildContext context,
    DateTime initialDate,
    bool isFrom,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final uiStyle = ref.watch(uiStyleProvider);
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        final baseTheme = Theme.of(context);
        final bool isLiquid = uiStyle == UiStyle.liquidGlass;

        final customizedTheme = Theme(
          data: baseTheme.copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isLiquid
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
                  : colorScheme.surfaceContainerHighest,
              elevation: isLiquid ? 0 : 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: isLiquid
                    ? BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      )
                    : BorderSide.none,
              ),
              headerBackgroundColor: Colors.transparent,
              headerForegroundColor: colorScheme.onSurface,
              headerHeadlineStyle: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              headerHelpStyle: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
              dayStyle: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              yearStyle: textTheme.bodyLarge,
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.onPrimary;
                }
                return colorScheme.primary;
              }),
              todayBorder: BorderSide(color: colorScheme.primary, width: 2),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.onPrimary;
                } else if (states.contains(WidgetState.disabled)) {
                  return colorScheme.onSurface.withValues(alpha: 0.38);
                }
                return colorScheme.onSurface;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.primary;
                }
                return Colors.transparent;
              }),
              dayOverlayColor: WidgetStateProperty.all(
                colorScheme.primary.withValues(alpha: 0.1),
              ),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.onPrimary;
                }
                return colorScheme.onSurface;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.primary;
                }
                return Colors.transparent;
              }),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onPrimaryContainer,
                backgroundColor: colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          child: child!,
        );

        if (isLiquid) {
          return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: customizedTheme,
          );
        }

        return customizedTheme;
      },
    );

    if (picked != null) {
      if (isFrom) {
        ref.read(dateCalculatorProvider.notifier).setFromDate(picked);
      } else {
        ref.read(dateCalculatorProvider.notifier).setToDate(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dateCalculatorProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;

    final cardTextColor = themeExt.resultText;

    final diff = state.preciseDifference;
    final isNegative = state.toDate.isBefore(state.fromDate);
    final totalDays = state.totalDays.abs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Date Difference'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () {
                _screenshotKey.currentState?.captureAndShare(
                  subject: 'Date Difference Calculation',
                  text:
                      'The difference between ${DateFormat.yMMMd().format(state.fromDate)} and ${DateFormat.yMMMd().format(state.toDate)} is $totalDays days.',
                );
              },
              tooltip: 'Share result',
            ),
          ),
        ],
      ),
      body: ScreenshotShareWrapper(
        key: _screenshotKey,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Inputs
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateSelector(
                          context,
                          label: 'From',
                          date: state.fromDate,
                          onTap: () =>
                              _selectDate(context, state.fromDate, true),
                          uiStyle: uiStyle,
                          colorScheme: colorScheme,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          onPressed: () => ref
                              .read(dateCalculatorProvider.notifier)
                              .swapDates(),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: _buildDateSelector(
                          context,
                          label: 'To',
                          date: state.toDate,
                          onTap: () =>
                              _selectDate(context, state.toDate, false),
                          uiStyle: uiStyle,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickAction(
                          context,
                          'Today',
                          () => ref
                              .read(dateCalculatorProvider.notifier)
                              .setToday(),
                          uiStyle,
                          colorScheme,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickAction(
                          context,
                          'Tomorrow',
                          () => ref
                              .read(dateCalculatorProvider.notifier)
                              .setTomorrow(),
                          uiStyle,
                          colorScheme,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickAction(
                          context,
                          'Yesterday',
                          () => ref
                              .read(dateCalculatorProvider.notifier)
                              .setYesterday(),
                          uiStyle,
                          colorScheme,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Result Card
                  SharedSurface(
                        uiStyle: uiStyle,
                        glassRole: GlassSurfaceRole.primary,
                        materialColor: themeExt.resultCard,
                        padding: const EdgeInsets.all(32),
                        borderRadius: BorderRadius.circular(32),
                        child: Column(
                          children: [
                            Text(
                              isNegative ? 'Difference (Past)' : 'Difference',
                              style: textTheme.titleMedium?.copyWith(
                                color: cardTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Total Days display
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    '$totalDays',
                                    key: ValueKey<int>(totalDays),
                                    style: textTheme.displayLarge?.copyWith(
                                      color: cardTextColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 64,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Days',
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: cardTextColor.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            Divider(
                              color: cardTextColor.withValues(alpha: 0.2),
                              thickness: 1,
                            ),
                            const SizedBox(height: 24),

                            // Precise breakdown
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                if (diff.years > 0)
                                  _buildTimeComponent(
                                    '${diff.years}',
                                    'Years',
                                    uiStyle,
                                    colorScheme,
                                    textTheme,
                                    cardTextColor,
                                  ),
                                if (diff.months > 0)
                                  _buildTimeComponent(
                                    '${diff.months}',
                                    'Months',
                                    uiStyle,
                                    colorScheme,
                                    textTheme,
                                    cardTextColor,
                                  ),
                                if (diff.days > 0 ||
                                    (diff.years == 0 && diff.months == 0))
                                  _buildTimeComponent(
                                    '${diff.days}',
                                    'Days',
                                    uiStyle,
                                    colorScheme,
                                    textTheme,
                                    cardTextColor,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOutQuad,
                      ),

                  const SizedBox(height: 24),

                  // Extra stats
                  SharedSurface(
                        uiStyle: uiStyle,
                        glassRole: GlassSurfaceRole.card,
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            _buildStatRow(
                              'Total Weeks',
                              '${state.totalWeeks.abs()} weeks, ${state.remainingDaysInWeek.abs()} days',
                              colorScheme,
                              textTheme,
                            ),
                            const Divider(height: 24),
                            _buildStatRow(
                              'Total Months',
                              '${state.totalMonths.abs().toStringAsFixed(2)} months',
                              colorScheme,
                              textTheme,
                            ),
                            const Divider(height: 24),
                            _buildStatRow(
                              'Total Years',
                              '${state.totalYears.abs().toStringAsFixed(2)} years',
                              colorScheme,
                              textTheme,
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOutQuad,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context, {
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required UiStyle uiStyle,
    required ColorScheme colorScheme,
  }) {
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.panel,
      isInteractive: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d, yyyy').format(date),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.calendar_today, size: 18, color: colorScheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    VoidCallback onTap,
    UiStyle uiStyle,
    ColorScheme colorScheme,
  ) {
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.button,
      isInteractive: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(20),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTimeComponent(
    String value,
    String unit,
    UiStyle uiStyle,
    ColorScheme colorScheme,
    TextTheme textTheme,
    Color cardTextColor,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: textTheme.headlineMedium?.copyWith(
            color: cardTextColor,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          unit,
          style: textTheme.bodyMedium?.copyWith(
            color: cardTextColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
