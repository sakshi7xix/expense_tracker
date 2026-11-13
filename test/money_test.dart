import 'package:flutter_test/flutter_test.dart';
import 'package:stub/core/money.dart';

void main() {
  group('formatInr', () {
    test('rounds to whole rupees by default', () {
      expect(formatInr(383000), '₹3,830');
      expect(formatInr(1117050), '₹11,171');
      expect(formatInr(1117049), '₹11,170');
      expect(formatInr(0), '₹0');
    });

    test('uses Indian grouping', () {
      expect(formatInr(1500000), '₹15,000');
      expect(formatInr(12345600), '₹1,23,456');
      expect(formatInr(12345678900), '₹12,34,56,789');
    });

    test('shows paise when asked', () {
      expect(formatInr(32650, decimals: true), '₹326.50');
      expect(formatInr(2000, decimals: true), '₹20.00');
      expect(formatInr(5, decimals: true), '₹0.05');
    });

    test('marks negative amounts', () {
      expect(formatInr(-4000), '−₹40');
    });
  });

  group('parseAmount', () {
    test('reads plain and decimal amounts', () {
      expect(parseAmount('120'), 12000);
      expect(parseAmount('349.5'), 34950);
      expect(parseAmount('349.50'), 34950);
      expect(parseAmount('.5'), 50);
    });

    test('ignores commas, spaces and the rupee sign', () {
      expect(parseAmount('1,200'), 120000);
      expect(parseAmount(' ₹ 80 '), 8000);
    });

    test('rejects anything that is not a positive amount', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('.'), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('12.345'), isNull);
      expect(parseAmount('-5'), isNull);
    });
  });
}
