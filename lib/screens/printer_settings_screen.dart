import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/printer_device.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/zywell_printer_service.dart'
    show PrinterStatus, PrinterStatusLabel, ZywellMessages;

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  bool _testing = false;
  PrinterDevice? _connectingTo;

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 16)),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _popup(String title, String msg) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg, style: const TextStyle(fontSize: 16)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Future<void> _scan() async {
    final printer = context.read<PrinterProvider>();
    // Explain why permissions are needed before Android asks.
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.bluetooth_searching, size: 40),
        title: const Text('Find your ZYWELL'),
        content: const Text(
          '${ZywellMessages.permissionsWhy}.\n\n'
          'Please allow Bluetooth / Nearby devices and Location when asked.\n\n'
          'Make sure the ZYWELL is ON. A blinking blue light means it is '
          'waiting to connect.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final error = await printer.startScan();
    if (error != null && mounted) {
      await _popup(
        error == ZywellMessages.bluetoothOffPopup
            ? 'Bluetooth is off'
            : 'Permission needed',
        error,
      );
    }
  }

  Future<void> _connect(PrinterDevice d) async {
    if (_connectingTo != null) return;
    setState(() => _connectingTo = d);
    final error = await context.read<PrinterProvider>().connect(d);
    if (!mounted) return;
    setState(() => _connectingTo = null);
    if (error == null) {
      _snack(
        'Connected to ${d.displayName}. The blue light should now stay ON.',
        color: Colors.green,
      );
    } else {
      await _popup('Not connected', '$error\n\n${ZywellMessages.pinHint}');
    }
  }

  Future<void> _testPrint() async {
    if (_testing) return;
    setState(() => _testing = true);
    final r = await context.read<PrinterProvider>().printTest(
      context.read<SettingsProvider>().receiptSettings,
    );
    if (!mounted) return;
    setState(() => _testing = false);
    if (r.success) {
      _snack(
        'Test receipt sent. Blank or strange print? See "Mode check" below.',
        color: Colors.green,
      );
    } else {
      await _popup('Test print failed', r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printer = context.watch<PrinterProvider>();
    final settings = context.watch<SettingsProvider>();
    final device = printer.device;
    final connected = printer.isConnected;
    final status = printer.status;

    return Scaffold(
      appBar: AppBar(title: const Text('Printer settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---------- Current ZYWELL
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current ZYWELL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.print,
                        size: 36,
                        color: connected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device?.displayName ?? 'No printer yet',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (device != null)
                              Text(
                                '${device.address} · '
                                '${device.link == PrinterLink.classic ? 'Bluetooth Classic' : 'BLE'}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            Text(
                              status.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: connected
                                    ? Colors.green
                                    : Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (device != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: connected
                              ? OutlinedButton(
                                  onPressed: printer.disconnect,
                                  child: const Text('Disconnect'),
                                )
                              : FilledButton(
                                  onPressed: status == PrinterStatus.connecting
                                      ? null
                                      : () => _connect(device),
                                  child: Text(
                                    status == PrinterStatus.connecting
                                        ? 'Connecting...'
                                        : 'Reconnect',
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: printer.forget,
                            child: const Text('Forget'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ---------- Scan
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: printer.scanning ? printer.stopScan : _scan,
                    icon: printer.scanning
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(
                      printer.scanning
                          ? '${ZywellMessages.scanning} (tap to stop)'
                          : 'Scan for ZYWELL',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Names can be ZY306, ZYWELL, ZM01, ZM04 or Printer_xxxx. '
                    '${ZywellMessages.pinHint}.',
                    style: TextStyle(fontSize: 15),
                  ),
                  if (printer.scanFinishedEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          ZywellMessages.notFound,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  for (final d in printer.devices)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 12,
                      leading: Icon(
                        d.link == PrinterLink.classic
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        size: 32,
                      ),
                      title: Text(
                        d.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${d.address} · ${d.link == PrinterLink.classic ? 'Paired (Classic)' : 'Nearby (BLE)'}',
                      ),
                      trailing: _connectingTo == d
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(96, 48),
                              ),
                              onPressed: () => _connect(d),
                              child: const Text('Connect'),
                            ),
                    ),
                ],
              ),
            ),
          ),

          // ---------- Paper size
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paper size',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Must match the paper actually inside the ZYWELL.',
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 80, label: Text('80mm (default)')),
                      ButtonSegment(value: 58, label: Text('58mm')),
                    ],
                    selected: {settings.paperMm},
                    onSelectionChanged: (s) => settings.setPaperMm(s.first),
                  ),
                ],
              ),
            ),
          ),

          // ---------- Auto-print + copies
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Auto-Print',
                    style: TextStyle(fontSize: 18),
                  ),
                  subtitle: const Text(
                    'Print the receipt right after checkout',
                  ),
                  value: settings.autoPrint,
                  onChanged: settings.setAutoPrint,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      const Text('Copies', style: TextStyle(fontSize: 18)),
                      const Spacer(),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1')),
                          ButtonSegment(value: 2, label: Text('2')),
                        ],
                        selected: {settings.copies},
                        onSelectionChanged: (s) => settings.setCopies(s.first),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------- Test print
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testPrint,
                icon: _testing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt),
                label: const Text('Print Test Receipt'),
              ),
            ),
          ),

          // ---------- Mode check
          Card(
            color: Colors.amber.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text(
                        'Mode check',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    ZywellMessages.modeCheck,
                    style: TextStyle(fontSize: 15),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Blue light ON = connected. Blue light blinking = NOT connected yet.\n'
                    'Faint print = battery low, please charge the ZYWELL.',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
