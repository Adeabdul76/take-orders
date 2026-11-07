import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/printer_settings_screen.dart';

/// Prints an order through PrinterProvider and shows a friendly result.
/// Never throws. Returns true if printed.
Future<bool> printOrderWithFeedback(BuildContext context, Order order) async {
  final printer = context.read<PrinterProvider>();
  final settings = context.read<SettingsProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final result = await printer.printReceipt(
    order,
    settings.receiptSettings,
    copies: settings.copies,
  );
  if (!context.mounted) return result.success;

  if (result.success) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Receipt ${order.number} printed',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.green,
      ),
    );
    return true;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.print_disabled, color: Colors.red, size: 40),
      title: const Text('Not printed'),
      content: Text(result.message, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
            );
          },
          child: const Text('Connect ZYWELL'),
        ),
      ],
    ),
  );
  return false;
}
