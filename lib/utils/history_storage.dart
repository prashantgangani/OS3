import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/simulation_history_entry.dart';

class HistoryStorage {
  static const String _historyKey = 'simulation_history_entries';
  static const int _maxEntries = 50;

  static Future<List<SimulationHistoryEntry>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => SimulationHistoryEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveEntry(SimulationHistoryEntry entry) async {
    final entries = await readAll();
    entries.insert(0, entry);
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, data);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}