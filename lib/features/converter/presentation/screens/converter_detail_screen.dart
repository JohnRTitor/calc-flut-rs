import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/converter/presentation/providers/converter_provider.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:calc_flut_rs/features/currency/presentation/widgets/utilities_keypad.dart';
import 'package:calc_flut_rs/features/converter/presentation/widgets/converter_result_card.dart';
import 'package:calc_flut_rs/features/converter/presentation/widgets/unit_selector_bottom_sheet.dart';
import 'package:calc_flut_rs/generated/rust/bridge/converter.dart';
import 'package:calc_flut_rs/shared/widgets/screenshot_share_wrapper.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_keypad_layout.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';

/// The detail screen for a specific converter category.
///
/// Displays the active "from" and "to" units, the calculated result, and provides
/// the keypad for numeric input. Also allows users to swap units or select new ones.
class ConverterDetailScreen extends ConsumerStatefulWidget {
  const ConverterDetailScreen({super.key});

  @override
  ConsumerState<ConverterDetailScreen> createState() =>
      _ConverterDetailScreenState();
}

class _ConverterDetailScreenState extends ConsumerState<ConverterDetailScreen> {
  final GlobalKey<ScreenshotShareWrapperState> _screenshotKey =
      GlobalKey<ScreenshotShareWrapperState>();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(converterProvider);
    final notifier = ref.read(converterProvider.notifier);
    final category = state.category;

    if (category == null) return const Scaffold();

    final uiStyle = ref.watch(uiStyleProvider);
    final colorScheme = Theme.of(context).colorScheme;

    Widget body = SafeArea(
      bottom: false,
      child: ResponsiveKeypadLayout(
        displayFlex: 55,
        keypadFlex: 45,
        keypadMinHeight: 350,
        displayArea: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 16.0,
            bottom: 16.0,
          ),
          child: _buildDisplayArea(
            context,
            ref,
            state,
            category,
            colorScheme,
            uiStyle,
          ),
        ),
        keypad: UtilitiesKeypad(
          onKeyPressed: (key) {
            if (key == '⌫') {
              notifier.onDelete();
            } else if (key == '.') {
              notifier.onDot();
            } else {
              notifier.onDigit(key);
            }
          },
        ),
      ),
    );

    void showRefreshToast(bool success) {
      toastification.showCustom(
        context: context,
        autoCloseDuration: const Duration(seconds: 3),
        alignment: Alignment.bottomCenter,
        builder: (context, holder) {
          return SharedSurface(
            uiStyle: uiStyle,
            glassRole: GlassSurfaceRole.panel,
            frosted: true,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  color: success ? colorScheme.primary : colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  success ? 'Exchange rates updated' : 'Failed to update rates',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    void showInfoDialog() {
      showAppDialog(
        context: context,
        uiStyle: uiStyle,
        title: 'Exchange Rates',
        icon: Icons.info_outline,
        content: Text(
          'Exchange rates are provided by Frankfurter API.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: [
          if (category.id == 'currency') ...[
            IconButton(
              icon: state.isLoadingRates
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: state.isLoadingRates
                  ? null
                  : () async {
                      final success = await notifier.refreshCurrencyRates();
                      if (context.mounted) {
                        showRefreshToast(success);
                      }
                    },
              tooltip: 'Refresh rates',
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: showInfoDialog,
              tooltip: 'Information',
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () {
                _screenshotKey.currentState?.captureAndShare(
                  subject: 'Check out this conversion!',
                  text:
                      'Check out this ${category.name} calculation from the Calculator app!',
                );
              },
              tooltip: 'Share screenshot',
            ),
          ),
        ],
      ),
      body: ScreenshotShareWrapper(
        key: _screenshotKey,
        child: Container(
          color: Theme.of(
            context,
          ).scaffoldBackgroundColor, // Ensure background is solid for screenshot
          child: body,
        ),
      ),
    );
  }

  Widget _buildDisplayArea(
    BuildContext context,
    WidgetRef ref,
    ConverterState state,
    FfiConverterCategory category,
    ColorScheme colorScheme,
    UiStyle uiStyle,
  ) {
    if (category.id == 'bmi') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompactInputCard(
            context,
            ref,
            label: state.bmiWeightUnit?.name ?? 'Weight',
            value: state.bmiWeight.isEmpty ? '0' : state.bmiWeight,
            symbol: state.bmiWeightUnit?.symbol ?? '',
            inputId: 'bmiWeight',
            isActive: state.activeInput == 'bmiWeight',
            colorScheme: colorScheme,
            uiStyle: uiStyle,
          ),
          const SizedBox(height: 12),
          _buildCompactInputCard(
            context,
            ref,
            label: state.bmiHeightUnit?.name ?? 'Height',
            value: state.bmiHeight.isEmpty ? '0' : state.bmiHeight,
            symbol: state.bmiHeightUnit?.symbol ?? '',
            inputId: 'bmiHeight',
            isActive: state.activeInput == 'bmiHeight',
            colorScheme: colorScheme,
            uiStyle: uiStyle,
          ),
          const SizedBox(height: 16),
          if (state.resultData != null && category.showResultSection)
            ConverterResultCard(
              data: state.resultData!,
              uiStyle: uiStyle,
              colorScheme: colorScheme,
            ),
        ],
      );
    }

    if (category.id == 'discount' || category.id == 'gst') {
      final isDiscount = category.id == 'discount';
      final topLabel = isDiscount ? 'Price' : 'Amount';
      final topInputId = isDiscount ? 'discountAmount' : 'gstAmount';
      final bottomLabel = 'Percentage';
      final bottomInputId = isDiscount ? 'discountPercentage' : 'gstPercentage';
      final topValue = state.inputValue.isEmpty ? '0' : state.inputValue;
      final bottomValue = (isDiscount
          ? state.discountPercentage
          : state.gstPercentage);

      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompactInputCard(
            context,
            ref,
            label: topLabel,
            value: topValue,
            symbol: '',
            inputId: topInputId,
            isActive: state.activeInput == topInputId,
            colorScheme: colorScheme,
            uiStyle: uiStyle,
            isSelectable: false,
          ),
          const SizedBox(height: 12),
          _buildCompactInputCard(
            context,
            ref,
            label: bottomLabel,
            value: bottomValue.isEmpty ? '0' : bottomValue,
            symbol: '%',
            inputId: bottomInputId,
            isActive: state.activeInput == bottomInputId,
            colorScheme: colorScheme,
            uiStyle: uiStyle,
            isSelectable: false,
          ),
          const SizedBox(height: 16),
          if (state.resultData != null && category.showResultSection)
            ConverterResultCard(
              data: state.resultData!,
              uiStyle: uiStyle,
              colorScheme: colorScheme,
            ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUnitSelectionRow(
          context,
          ref,
          state,
          category,
          colorScheme,
          uiStyle,
        ),
        const SizedBox(height: 16),
        _buildInputCard(
          context,
          ref,
          value: state.inputValue.isEmpty ? '0' : state.inputValue,
          symbol: state.fromUnit?.symbol ?? '',
          inputId: 'from',
          isActive: state.activeInput == 'from',
          colorScheme: colorScheme,
          uiStyle: uiStyle,
        ),
        const SizedBox(height: 16),
        if (state.resultData != null && category.showResultSection)
          ConverterResultCard(
            data: state.resultData!,
            uiStyle: uiStyle,
            colorScheme: colorScheme,
            isActive: state.activeInput == 'to',
            onTap: () =>
                ref.read(converterProvider.notifier).setActiveInput('to'),
          ),
      ],
    );
  }

  Widget _buildUnitSelectionRow(
    BuildContext context,
    WidgetRef ref,
    ConverterState state,
    FfiConverterCategory category,
    ColorScheme colorScheme,
    UiStyle uiStyle,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildUnitSelectorButton(
            context,
            ref,
            label: state.fromUnit?.name ?? 'Select unit',
            inputId: 'from',
            colorScheme: colorScheme,
            uiStyle: uiStyle,
          ),
        ),
        if (category.showSwapUnitsToggler)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => ref.read(converterProvider.notifier).swapUnits(),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        if (!category.showSwapUnitsToggler) const SizedBox(width: 16),
        Expanded(
          child: _buildUnitSelectorButton(
            context,
            ref,
            label: state.toUnit?.name ?? 'Select unit',
            inputId: 'to',
            colorScheme: colorScheme,
            uiStyle: uiStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelectorButton(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String inputId,
    required ColorScheme colorScheme,
    required UiStyle uiStyle,
  }) {
    return SharedSurface(
      uiStyle: uiStyle,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      glassRole: GlassSurfaceRole.panel,
      materialColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(24),
      frosted: true,
      isInteractive: true,
      onTap: () => _showUnitSelector(context, ref, inputId),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(
    BuildContext context,
    WidgetRef ref, {
    required String value,
    required String symbol,
    required String inputId,
    required bool isActive,
    required ColorScheme colorScheme,
    required UiStyle uiStyle,
  }) {
    final valueColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => ref.read(converterProvider.notifier).setActiveInput(inputId),
      child: SharedSurface(
        uiStyle: uiStyle,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        glassRole: isActive ? GlassSurfaceRole.primary : GlassSurfaceRole.card,
        materialColor: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  isActive ? '$value|' : value,
                  key: ValueKey<String>('${value}_$isActive'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 56, // Match 48-64sp typography
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              symbol,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactInputCard(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String value,
    required String symbol,
    required String inputId,
    required bool isActive,
    required ColorScheme colorScheme,
    required UiStyle uiStyle,
    bool isSelectable = true,
  }) {
    final valueColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => ref.read(converterProvider.notifier).setActiveInput(inputId),
      child: SharedSurface(
        uiStyle: uiStyle,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        glassRole: isActive ? GlassSurfaceRole.primary : GlassSurfaceRole.card,
        materialColor: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: isSelectable
                  ? () => _showUnitSelector(context, ref, inputId)
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isSelectable) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: secondaryTextColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        isActive ? '$value|' : value,
                        key: ValueKey<String>('${value}_$isActive'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: valueColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 32,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ),
                    if (symbol.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        symbol,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitSelector(BuildContext context, WidgetRef ref, String inputId) {
    final state = ref.read(converterProvider);
    final category = state.category;
    if (category == null) return;

    final List<FfiUnit> units;
    FfiUnit? selectedUnit;

    if (category.id == 'bmi') {
      if (inputId == 'bmiWeight') {
        units = bmiWeightUnits;
        selectedUnit = state.bmiWeightUnit;
      } else {
        units = bmiHeightUnits;
        selectedUnit = state.bmiHeightUnit;
      }
    } else {
      units = category.units;
      selectedUnit = inputId == 'from' ? state.fromUnit : state.toUnit;
    }

    if (units.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        final uiStyle = ref.watch(uiStyleProvider);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 12,
            right: 12,
            top: MediaQuery.of(context).padding.top + 24,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: UnitSelectorBottomSheet(
              units: units,
              selectedUnit: selectedUnit,
              categoryId: category.id,
              uiStyle: uiStyle,
              onSelect: (unit) {
                final notifier = ref.read(converterProvider.notifier);
                if (category.id == 'bmi') {
                  if (inputId == 'bmiWeight') {
                    notifier.setBmiWeightUnit(unit);
                  } else {
                    notifier.setBmiHeightUnit(unit);
                  }
                } else {
                  if (inputId == 'from') {
                    notifier.setFromUnit(unit);
                  } else {
                    notifier.setToUnit(unit);
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}
