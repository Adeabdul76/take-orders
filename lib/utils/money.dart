/// Formats cents as "RM 14.00" or "MYR 14.00".
String formatMoney(int cents, String currency) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final sen = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$currency $whole.$sen';
}

/// Parses what the user typed ("8", "8.5", "8.50", "RM 8.50") into cents.
/// Returns null if it is not a valid amount.
int? parseMoneyToCents(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[^0-9.,]'), '')
      .replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final match = RegExp(r'^(\d{0,7})(?:\.(\d{0,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!.isEmpty ? '0' : match.group(1)!);
  final fracRaw = match.group(2) ?? '';
  final frac = int.parse(
    fracRaw.padRight(2, '0').isEmpty ? '0' : fracRaw.padRight(2, '0'),
  );
  if (whole == null) return null;
  return whole * 100 + frac;
}
