import 'package:flutter_test/flutter_test.dart';

import 'package:pfa_pharmacy_invoice_tracker/core/format.dart';

void main() {
  group('numberToWords', () {
    test('handles small numbers', () {
      expect(numberToWords(0), 'Zero');
      expect(numberToWords(7), 'Seven');
      expect(numberToWords(12), 'Twelve');
      expect(numberToWords(19), 'Nineteen');
      expect(numberToWords(20), 'Twenty');
      expect(numberToWords(34), 'Thirty-Four');
    });

    test('handles hundreds', () {
      expect(numberToWords(100), 'One Hundred');
      expect(numberToWords(125), 'One Hundred And Twenty-Five');
      expect(numberToWords(205), 'Two Hundred And Five');
    });

    test('handles thousands and above', () {
      expect(numberToWords(1000), 'One Thousand');
      expect(numberToWords(1250), 'One Thousand Two Hundred And Fifty');
      expect(numberToWords(2050), 'Two Thousand And Fifty');
      expect(
        numberToWords(1234567),
        'One Million Two Hundred And Thirty-Four Thousand '
        'Five Hundred And Sixty-Seven',
      );
      expect(
        numberToWords(1002000300),
        'One Billion Two Million Three Hundred',
      );
    });

    test('handles negatives', () {
      expect(numberToWords(-34), 'Minus Thirty-Four');
    });
  });

  group('moneyInWords', () {
    test('zero amount', () {
      expect(moneyInWords(0), 'Zero Ghana Cedis Only');
    });

    test('cedis only', () {
      expect(
        moneyInWords(123400),
        'One Thousand Two Hundred And Thirty-Four Ghana Cedis Only',
      );
      expect(
        moneyInWords(100000),
        'One Thousand Ghana Cedis Only',
      );
    });

    test('pesewas only', () {
      expect(moneyInWords(50), 'Fifty Pesewas Only');
      expect(moneyInWords(99), 'Ninety-Nine Pesewas Only');
    });

    test('cedis and pesewas', () {
      expect(
        moneyInWords(123450),
        'One Thousand Two Hundred And Thirty-Four Ghana Cedis '
        'And Fifty Pesewas Only',
      );
      expect(
        moneyInWords(10005),
        'One Hundred Ghana Cedis And Five Pesewas Only',
      );
    });
  });
}