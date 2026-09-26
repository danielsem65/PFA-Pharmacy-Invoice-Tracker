import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/data/app_database.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/business_profile.dart';
import 'package:pfa_pharmacy_invoice_tracker/models/print_settings.dart';

/// A key/value store with no platform channel behind it.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late MemoryKeyValueStore prefs;
  late SharedPrefsLocalStore store;

  setUp(() {
    prefs = MemoryKeyValueStore();
    store = SharedPrefsLocalStore(prefs);
  });

  group('business profile', () {
    test('starts empty on a fresh install', () async {
      final profile = await store.loadProfile();

      expect(profile.isEmpty, isTrue);
      expect(profile.name, '');
    });

    test('saves and reads back every field', () async {
      await store.saveProfile(
        BusinessProfile(
          name: 'PFA Pharmacy',
          address: '12 Oxford Street',
          phone: '030 123 4567',
          email: 'pfa@example.com',
          tin: 'C0012345',
        ),
      );

      final loaded = await store.loadProfile();
      expect(loaded.name, 'PFA Pharmacy');
      expect(loaded.address, '12 Oxford Street');
      expect(loaded.phone, '030 123 4567');
      expect(loaded.email, 'pfa@example.com');
      expect(loaded.tin, 'C0012345');
    });

    test('an overwrite replaces the old details', () async {
      await store.saveProfile(BusinessProfile(name: 'Old Name'));
      await store.saveProfile(BusinessProfile(name: 'New Name'));

      expect((await store.loadProfile()).name, 'New Name');
    });

    test('a damaged record falls back to an empty profile, not a crash',
        () async {
      prefs.values['pfa.profile.v1'] = 'this is not json';

      final profile = await store.loadProfile();
      expect(profile.isEmpty, isTrue);
    });

    test('a record missing fields does not fail to load', () async {
      prefs.values['pfa.profile.v1'] = '{"name":"PFA Pharmacy"}';

      final profile = await store.loadProfile();
      expect(profile.name, 'PFA Pharmacy');
      expect(profile.phone, '');
    });
  });

  group('print settings', () {
    test('starts with no default layout, so the app asks', () async {
      final settings = await store.loadPrintSettings();

      expect(settings.defaultLayout, isNull);
      expect(settings.remembersLayout, isFalse);
    });

    test('saves and reads back the chosen layout', () async {
      await store.savePrintSettings(
        PrintSettings(defaultLayout: InvoicePrintLayout.paymentVoucher),
      );

      final loaded = await store.loadPrintSettings();
      expect(loaded.defaultLayout, InvoicePrintLayout.paymentVoucher);
      expect(loaded.remembersLayout, isTrue);
    });

    test('every layout survives the round trip by name', () async {
      for (final layout in InvoicePrintLayout.values) {
        await store.savePrintSettings(PrintSettings(defaultLayout: layout));
        expect(
          (await store.loadPrintSettings()).defaultLayout,
          layout,
          reason: layout.name,
        );
      }
    });

    test('a damaged record falls back to no default', () async {
      prefs.values['pfa.print.v1'] = '{oops';

      final settings = await store.loadPrintSettings();
      expect(settings.defaultLayout, isNull);
    });

    test('an unknown stored layout is treated as no default', () async {
      prefs.values['pfa.print.v1'] = '{"defaultLayout":"fromTheFuture"}';

      final settings = await store.loadPrintSettings();
      expect(settings.defaultLayout, isNull);
    });
  });

  group('PrintSettings', () {
    test('copyWith keeps the layout unless it is cleared', () {
      final settings = PrintSettings(
        defaultLayout: InvoicePrintLayout.splitLedger,
      );

      expect(
        settings.copyWith().defaultLayout,
        InvoicePrintLayout.splitLedger,
      );
      expect(
        settings.copyWith(
          defaultLayout: InvoicePrintLayout.classicForm,
        ).defaultLayout,
        InvoicePrintLayout.classicForm,
      );
      expect(settings.copyWith(clearDefaultLayout: true).defaultLayout, isNull);
    });

    test('every layout has a label and a blurb for the picker', () {
      for (final layout in InvoicePrintLayout.values) {
        expect(layout.label, isNotEmpty);
        expect(layout.blurb, isNotEmpty);
        expect(
          InvoicePrintLayout.fromStorage(layout.storageValue),
          layout,
        );
      }
    });

    test('an unknown stored name does not resolve to a layout', () {
      expect(InvoicePrintLayout.fromStorage('nope'), isNull);
      expect(InvoicePrintLayout.fromStorage(null), isNull);
    });
  });
}
