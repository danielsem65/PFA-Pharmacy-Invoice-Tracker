import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/print_settings.dart';

/// How the print button behaves: ask every time, or go straight to one layout.
class PrintSettingsController extends StateNotifier<PrintSettings> {
  PrintSettingsController(this._store) : super(PrintSettings()) {
    _load();
  }

  final LocalStore _store;

  Future<void> _load() async {
    state = await _store.loadPrintSettings();
  }

  Future<void> refresh() => _load();

  /// Passing null clears the default, which sends the app back to asking.
  Future<void> setDefaultLayout(InvoicePrintLayout? layout) async {
    state = state.copyWith(
      defaultLayout: layout,
      clearDefaultLayout: layout == null,
    );
    await _store.savePrintSettings(state);
  }
}

final printSettingsProvider =
    StateNotifierProvider<PrintSettingsController, PrintSettings>((ref) {
  return PrintSettingsController(ref.watch(localStoreProvider));
});
