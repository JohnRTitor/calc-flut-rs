import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:calc_flut_rs/app/navigation/route_transitions.dart';
import 'package:calc_flut_rs/app/navigation/tool_registry.dart';
import 'package:calc_flut_rs/app/navigation/tool_search_delegate.dart';
import 'package:calc_flut_rs/app/providers/section_provider.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/screens/settings_screen.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';
import 'package:calc_flut_rs/shared/widgets/app_dropdown_menu.dart';
import 'package:calc_flut_rs/shared/widgets/app_navigation.dart';

/// The adaptive navigation shell of the application.
///
/// The layout is chosen from the available width using the shared
/// [AppBreakpoints]:
///
/// | Width          | Layout                                     |
/// |----------------|--------------------------------------------|
/// | `< 600`        | Hamburger + modal [AppNavigationDrawer]   |
/// | `600 - 840`    | Persistent icon-only [AppNavigationRail]   |
/// | `> 840`        | Extended [AppNavigationRail] (icon + label) |
///
/// Sections are hosted in an [IndexedStack] so each one keeps its own scroll
/// position and in-progress state while the user moves between them. The
/// destination list, the hub grids and the tool search all read from
/// [appSections], so adding a section or a tool never requires changing this
/// widget.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<AppSection> get _sections => appSections;

  List<AppNavDestination> get _destinations => _sections
      .map(
        (section) => AppNavDestination(
          id: section.id,
          label: section.label,
          icon: section.icon,
        ),
      )
      .toList();

  AppSection? get _selectedSection {
    final selectedId = ref.watch(selectedSectionProvider);
    return appSectionById(selectedId);
  }

  void _selectSection(String id) {
    ref.read(selectedSectionProvider.notifier).select(id);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSearch() async {
    final uiStyle = ref.read(uiStyleProvider);
    final tool = await showSearch<AppTool?>(
      context: context,
      delegate: AppToolSearchDelegate(uiStyle: uiStyle),
    );

    if (tool == null || !mounted) return;
    await tool.open(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final sections = _sections;
    final section = _selectedSection;

    if (section == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final classification = constraints.isCompactWidth
            ? ScreenSize.compact
            : constraints.isExpandedWidth
            ? ScreenSize.expanded
            : ScreenSize.medium;

        return Scaffold(
          key: _scaffoldKey,
          drawer: classification == ScreenSize.compact
              ? AppNavigationDrawer(
                  uiStyle: uiStyle,
                  destinations: _destinations,
                  selectedId: section.id,
                  onSelected: _selectSection,
                  onSearch: _openSearch,
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (classification != ScreenSize.compact) ...[
                  SizedBox(
                    width: classification == ScreenSize.expanded ? 200 : 80,
                    child: AppNavigationRail(
                      uiStyle: uiStyle,
                      destinations: _destinations,
                      selectedId: section.id,
                      onSelected: _selectSection,
                      onSearch: _openSearch,
                      extended: classification == ScreenSize.expanded,
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                ],
                Expanded(
                  child: Column(
                    children: [
                      _buildSectionAppBar(
                        context: context,
                        uiStyle: uiStyle,
                        section: section,
                        showMenuButton: classification == ScreenSize.compact,
                      ),
                      Expanded(
                        child: IndexedStack(
                          // Section roots are viewports (grids, calculators).
                          // They have no intrinsic size, so under the default
                          // StackFit.loose they would collapse to zero and trip
                          // the sliver layout assertions. Expand forces tight
                          // constraints on every child, visible or maintained.
                          sizing: StackFit.expand,
                          index: sections.indexOf(section),
                          children: [
                            for (final item in sections)
                              Builder(builder: item.builder),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionAppBar({
    required BuildContext context,
    required UiStyle uiStyle,
    required AppSection section,
    required bool showMenuButton,
  }) {
    return AppBar(
      toolbarHeight: 56,
      title: Text(section.label),
      leading: showMenuButton
          ? IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open navigation menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search tools',
          onPressed: _openSearch,
        ),
        AppDropdownMenu(
          icon: Icons.more_vert,
          uiStyle: uiStyle,
          tooltip: 'More options',
          entries: [
            AppDropdownMenuEntry(
              label: 'Settings',
              onPressed: () => Navigator.push(
                context,
                FadePageRoute(page: const SettingsScreen()),
              ),
            ),
            AppDropdownMenuEntry(
              label: 'About',
              onPressed: () => _showAboutDialog(context, uiStyle),
            ),
          ],
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context, UiStyle uiStyle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showAppDialog(
      context: context,
      title: 'About',
      icon: Icons.info_outline,
      uiStyle: uiStyle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masum Reza (JohnRTitor)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Flutter + Rust Native Calculator\nBuilt for performance and elegance.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
      primaryButtonText: 'View Source Code',
      onPrimaryButtonPressed: () async {
        final url = Uri.parse('https://github.com/JohnRTitor/calc_flut_rs');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      secondaryButtonText: 'Close',
    );
  }
}
