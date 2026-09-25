import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'section_provider.g.dart';

/// The id of the section shown when no persisted selection exists.
const String kDefaultSectionId = 'calculator';

/// Remembers which top level section of the app shell was last visible.
///
/// Persisted to SharedPreferences so relaunching the app returns the user to
/// where they left off. Unknown or stale ids fall back to [kDefaultSectionId].
@riverpod
class SelectedSectionNotifier extends _$SelectedSectionNotifier {
  @override
  String build() {
    _load();
    return kDefaultSectionId;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('selected_section');
    if (id != null && id.isNotEmpty) {
      state = id;
    }
  }

  /// Selects [sectionId] and persists it.
  Future<void> select(String sectionId) async {
    if (state == sectionId) return;
    state = sectionId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_section', sectionId);
  }
}
