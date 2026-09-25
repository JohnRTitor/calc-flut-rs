import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/navigation/tool_registry.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_navigation.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// Search delegate over every tool in `appSections`.
///
/// Pops the selected [AppTool] (or `null` when dismissed) so the caller decides
/// how to open it — the shell pushes it from the app bar or drawer.
class AppToolSearchDelegate extends SearchDelegate<AppTool?> {
  final UiStyle uiStyle;

  AppToolSearchDelegate({required this.uiStyle})
    : super(
        searchFieldLabel: 'Search tools',
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
      );

  /// All searchable entries: every tool, tagged with the section that owns it.
  static List<_SearchEntry> get _entries => [
    for (final section in appSections)
      for (final tool in section.tools)
        _SearchEntry(section: section, tool: tool),
  ];

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = super.appBarTheme(context);
    if (uiStyle != UiStyle.liquidGlass) {
      return base;
    }

    // Let the app-wide glass background show through the search surface.
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();

    final matches = normalizedQuery.isEmpty
        ? _entries
        : _entries.where((entry) {
            return entry.tool.label.toLowerCase().contains(normalizedQuery) ||
                entry.section.label.toLowerCase().contains(normalizedQuery);
          }).toList();

    final colorScheme = Theme.of(context).colorScheme;

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.panel,
      glassColor: resolveOverlaySurfaceFill(colorScheme),
      frosted: true,
      borderRadius: BorderRadius.zero,
      child: matches.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tools match "$query".',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final entry = matches[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: SharedSurface(
                    uiStyle: uiStyle,
                    glassRole: GlassSurfaceRole.card,
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => close(context, entry.tool),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(entry.tool.icon, size: 22),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.tool.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                entry.section.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (!entry.tool.isAvailable)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              'Soon',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// A tool paired with the section that owns it, so results can show which
/// section a tool lives in.
@immutable
class _SearchEntry {
  final AppSection section;
  final AppTool tool;

  const _SearchEntry({required this.section, required this.tool});
}
