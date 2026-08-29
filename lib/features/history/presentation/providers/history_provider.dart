import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';
import 'package:calc_flut_rs/generated/rust/bridge/history.dart'
    as bridge;

part 'history_provider.g.dart';

/// A Riverpod Notifier that manages the history of calculations.
///
/// Interacts with the Rust backend to load, save, clear, and delete history entries.
@Riverpod(keepAlive: true)
class History extends _$History {
  @override
  Future<List<HistoryEntry>> build() async {
    try {
      final file = await _getHistoryFile();
      await bridge.appHistoryLoad(path: file.path);
    } catch (_) {}
    return bridge.appHistoryGetAll();
  }

  Future<File> _getHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/calc_app_history.json');
  }

  Future<void> saveHistoryToFile() async {
    try {
      final file = await _getHistoryFile();
      await bridge.appHistorySave(path: file.path);
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = AsyncData(bridge.appHistoryGetAll());
  }

  Future<void> delete(String id) async {
    bridge.appHistoryDelete(id: id);
    await saveHistoryToFile();
    await refresh();
  }

  Future<void> clearCategory(String category) async {
    bridge.appHistoryClearCategory(category: category);
    await saveHistoryToFile();
    await refresh();
  }

  Future<void> clearAll() async {
    bridge.appHistoryClearAll();
    await saveHistoryToFile();
    await refresh();
  }
}
