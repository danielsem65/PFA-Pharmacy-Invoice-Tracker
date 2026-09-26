import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/app_preferences.dart';

/// How the app is lit, remembered between runs.
class AppPreferencesController extends StateNotifier<AppPreferences> {
  AppPreferencesController(this._store) : super(AppPreferences()) {
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
    state = await _store.loadPreferences();
  }

  Future<void> refresh() => _enqueue(_read);

  /// The sky changes immediately and the write follows, so waiting for the disk
  /// never leaves the app looking like the tap did nothing.
  Future<void> setTheme(AppTheme theme) {
    return _enqueue(() async {
      state = state.copyWith(theme: theme);
      await _store.savePreferences(state);
    });
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesController, AppPreferences>((ref) {
  return AppPreferencesController(ref.watch(localStoreProvider));
});
