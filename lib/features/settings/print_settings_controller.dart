import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/print_settings.dart';

/// How the print button behaves: ask every time, or go straight to one layout.
class PrintSettingsController extends StateNotifier<PrintSettings> {
  PrintSettingsController(this._store) : super(PrintSettings()) {
    _enqueue(_read);
  }

  final LocalStore _store;

  /// Store calls run one after another, so the first load cannot land on top of
  /// a change the user already made.
  Future<void> _queue = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() step) {
    final result = _queue.then((_) => step());
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _read() async {
    state = await _store.loadPrintSettings();
  }

  Future<void> refresh() => _enqueue(_read);

  /// Passing null clears the default, which sends the app back to asking.
  Future<void> setDefaultLayout(InvoicePrintLayout? layout) {
    return _enqueue(() async {
      state = state.copyWith(
        defaultLayout: layout,
        clearDefaultLayout: layout == null,
      );
      await _store.savePrintSettings(state);
    });
  }
}

final printSettingsProvider =
    StateNotifierProvider<PrintSettingsController, PrintSettings>((ref) {
  return PrintSettingsController(ref.watch(localStoreProvider));
});
