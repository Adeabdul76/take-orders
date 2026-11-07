import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/printer_provider.dart';
import '../screens/printer_settings_screen.dart';
import '../services/zywell_printer_service.dart'
    show PrinterStatus, ZywellMessages;

/// Orange banner shown when the ZYWELL is not connected. Tap to connect.
class PrinterStatusBanner extends StatelessWidget {
  const PrinterStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final printer = context.watch<PrinterProvider>();
    if (printer.isConnected) return const SizedBox.shrink();
    final connecting = printer.status == PrinterStatus.connecting;
    return Material(
      color: Colors.orange.shade100,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              connecting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_disabled, color: Colors.deepOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connecting
                      ? 'Connecting to ${printer.device?.displayName ?? 'ZYWELL'}...'
                      : ZywellMessages.notConnected,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Printer icon for the app bar: green = connected, grey = not connected.
class PrinterIconButton extends StatelessWidget {
  const PrinterIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final printer = context.watch<PrinterProvider>();
    final connected = printer.isConnected;
    return IconButton(
      tooltip: connected ? 'ZYWELL connected' : 'ZYWELL not connected',
      iconSize: 30,
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: connected ? Colors.green : Colors.grey.shade500,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.print, color: Colors.white),
      ),
    );
  }
}

/// Listens for unexpected disconnects (often low battery) and warns once.
class PrinterDisconnectListener extends StatefulWidget {
  final Widget child;
  const PrinterDisconnectListener({super.key, required this.child});

  @override
  State<PrinterDisconnectListener> createState() =>
      _PrinterDisconnectListenerState();
}

class _PrinterDisconnectListenerState extends State<PrinterDisconnectListener> {
  PrinterProvider? _printer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<PrinterProvider>();
    if (p != _printer) {
      _printer?.removeListener(_check);
      _printer = p..addListener(_check);
    }
  }

  void _check() {
    final msg = _printer?.lastWarning;
    if (msg == null || !mounted) return;
    _printer!.clearWarning();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.deepOrange,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  void dispose() {
    _printer?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
