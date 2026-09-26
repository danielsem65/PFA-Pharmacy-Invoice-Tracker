/// How a printed invoice is laid out. Three shapes, because a copy you file
/// and a voucher you hand to a supplier are not the same document.
enum InvoicePrintLayout {
  classicForm('Classic form'),
  splitLedger('Split ledger'),
  paymentVoucher('Payment voucher');

  const InvoicePrintLayout(this.label);

  /// Shown in the layout picker and in Settings.
  final String label;

  /// The longer explanation, so the choice is obvious in the picker.
  String get blurb {
    switch (this) {
      case InvoicePrintLayout.classicForm:
        return 'Boxed details up top, a full-width item table, and the totals '
            'boxed at the bottom right. The familiar accounting layout.';
      case InvoicePrintLayout.splitLedger:
        return 'Details sit in a narrow column down the left so product names '
            'get the wide side of the page.';
      case InvoicePrintLayout.paymentVoucher:
        return 'For handing to the supplier. Leads with the amount paid, what '
            'it settles, and where the balance stands afterwards.';
    }
  }

  String get storageValue => name;

  static InvoicePrintLayout? fromStorage(String? value) {
    if (value == null) return null;
    for (final layout in InvoicePrintLayout.values) {
      if (layout.storageValue == value) return layout;
    }
    return null;
  }
}

/// How printing behaves by default. A null [defaultLayout] means the app asks
/// which layout to use every time, which is the sensible starting point.
class PrintSettings {
  PrintSettings({this.defaultLayout});

  final InvoicePrintLayout? defaultLayout;

  bool get remembersLayout => defaultLayout != null;

  PrintSettings copyWith({
    InvoicePrintLayout? defaultLayout,
    bool clearDefaultLayout = false,
  }) {
    return PrintSettings(
      defaultLayout: clearDefaultLayout ? null : defaultLayout ?? this.defaultLayout,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'defaultLayout': defaultLayout?.storageValue,
      };

  factory PrintSettings.fromJson(Map<String, dynamic> json) {
    return PrintSettings(
      defaultLayout: InvoicePrintLayout.fromStorage(
        json['defaultLayout'] as String?,
      ),
    );
  }
}
