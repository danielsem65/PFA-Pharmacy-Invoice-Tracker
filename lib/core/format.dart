import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(
  symbol: '₵',
  decimalDigits: 2,
);

final DateFormat _date = DateFormat('dd/MM/yyyy');

String formatPesewas(int pesewas) => _money.format(pesewas / 100);

String formatDate(DateTime date) => _date.format(date);

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

const List<String> _ones = [
  'Zero',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];

const List<String> _tens = [
  '',
  '',
  'Twenty',
  'Thirty',
  'Forty',
  'Fifty',
  'Sixty',
  'Seventy',
  'Eighty',
  'Ninety',
];

const List<String> _scales = [
  '',
  'Thousand',
  'Million',
  'Billion',
  'Trillion',
];

String _belowHundred(int n) {
  if (n < 20) return _ones[n];
  if (n % 10 == 0) return _tens[n ~/ 10];
  return '${_tens[n ~/ 10]}-${_ones[n % 10]}';
}

String _belowThousand(int n) {
  final h = n ~/ 100;
  final r = n % 100;
  if (h == 0) return _belowHundred(r);
  if (r == 0) return '${_ones[h]} Hundred';
  return '${_ones[h]} Hundred And ${_belowHundred(r)}';
}

/// Converts a whole number to its English words, e.g. 1250 -> "One Thousand Two Hundred And Fifty".
String numberToWords(int n) {
  if (n < 0) return 'Minus ${numberToWords(-n)}';
  if (n == 0) return 'Zero';

  final chunks = <int>[];
  var v = n;
  while (v > 0) {
    chunks.add(v % 1000);
    v ~/= 1000;
  }
  final parts = <String>[];
  for (var i = chunks.length - 1; i >= 0; i--) {
    final c = chunks[i];
    if (c == 0) continue;
    final text = _belowThousand(c);
    parts.add(_scales[i].isEmpty ? text : '$text ${_scales[i]}');
  }
  return parts.join(' ');
}

/// Converts an amount in pesewas to words, e.g. 123450 -> "One Thousand Two Hundred And Thirty-Four Ghana Cedis And Fifty Pesewas Only".
String moneyInWords(int pesewas) {
  final cedis = pesewas ~/ 100;
  final pesewasPart = pesewas % 100;
  if (cedis == 0 && pesewasPart == 0) return 'Zero Ghana Cedis Only';

  final b = StringBuffer();
  if (cedis > 0) {
    b.write('${numberToWords(cedis)} Ghana Cedis');
  }
  if (pesewasPart > 0) {
    if (cedis > 0) b.write(' And ');
    b.write('${numberToWords(pesewasPart)} Pesewas');
  }
  b.write(' Only');
  return b.toString();
}