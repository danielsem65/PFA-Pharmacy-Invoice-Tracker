import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../models/business_profile.dart';

/// The pharmacy's own details, used in the header of every printed invoice.
class BusinessProfileController extends StateNotifier<BusinessProfile> {
  BusinessProfileController(this._store) : super(BusinessProfile()) {
    _load();
  }

  final LocalStore _store;

  Future<void> _load() async {
    state = await _store.loadProfile();
  }

  Future<void> refresh() => _load();

  Future<void> save(BusinessProfile profile) async {
    state = profile;
    await _store.saveProfile(profile);
  }
}

final businessProfileProvider =
    StateNotifierProvider<BusinessProfileController, BusinessProfile>((ref) {
  return BusinessProfileController(ref.watch(localStoreProvider));
});
