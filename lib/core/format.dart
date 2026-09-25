import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(
  symbol: '₵',
  decimalDigits: 2,
);

final DateFormat _date = DateFormat('dd/MM/yyyy');

String formatPesewas(int pesewas) => _money.format(pesewas / 100);

String formatDate(DateTime date) => _date.format(date);

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);