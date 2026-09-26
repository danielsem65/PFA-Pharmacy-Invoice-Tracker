import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/business_profile.dart';

/// The pharmacy's own details, used in the header of every printed invoice.
class BusinessProfileController extends StateNotifier<BusinessProfile> {
  BusinessProfileController(this._store) : super(BusinessProfile()) {
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
    state = await _store.loadProfile();
  }

  Future<void> refresh() => _enqueue(_read);

  Future<void> save(BusinessProfile profile) {
    return _enqueue(() async {
      state = profile;
      await _store.saveProfile(profile);
    });
  }
}

final businessProfileProvider =
    StateNotifierProvider<BusinessProfileController, BusinessProfile>((ref) {
  return BusinessProfileController(ref.watch(localStoreProvider));
});
