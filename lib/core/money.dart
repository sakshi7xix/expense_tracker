/// Money helpers. Every amount in the app is stored as whole paise (int),
/// so ₹1 is 100. Never store or add rupees as doubles.
library;

/// Formats [paise] as rupees with Indian digit grouping, e.g. ₹1,23,456.
/// Without [decimals] the amount is rounded to the nearest rupee.
String formatInr(int paise, {bool decimals = false}) {
  final negative = paise < 0;
  final abs = paise.abs();
  var rupees = abs ~/ 100;
  final rest = abs % 100;
  if (!decimals && rest >= 50) rupees += 1;
  final grouped = _groupIndian(rupees);
  final body = decimals
      ? '₹$grouped.${rest.toString().padLeft(2, '0')}'
      : '₹$grouped';
  return negative ? '−$body' : body;
}

String _groupIndian(int rupees) {
  final digits = rupees.toString();
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${parts.join(',')},$lastThree';
}

final _amountPattern = RegExp(r'^\d*\.?\d{0,2}$');
final _amountNoise = RegExp(r'[,\s₹]');

/// Parses what a person typed ("120", "349.5", "1,200") into paise.
/// Returns null for anything that is not a positive amount with at most
/// two decimal places.
int? parseAmount(String input) {
  final text = input.replaceAll(_amountNoise, '');
  if (text.isEmpty || text == '.' || !_amountPattern.hasMatch(text)) {
    return null;
  }
  final parts = text.split('.');
  final rupees = parts[0].isEmpty ? 0 : int.parse(parts[0]);
  final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  final paise = rupees * 100 + int.parse(fraction);
  return paise > 0 ? paise : null;
}
