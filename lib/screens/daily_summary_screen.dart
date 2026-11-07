import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/daily_summary.dart';
import '../models/order.dart';
import '../providers/cafe_provider.dart';
import '../providers/order_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/money.dart';
import 'printer_settings_screen.dart';

/// End-of-day totals: sales, orders, payment types, best sellers.
/// In a shared cafe it includes orders from ALL phones.
class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  late DateTime _day;
  Stream<List<Order>>? _stream;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _load();
  }

  void _load() {
    _stream = context.read<OrderProvider>().ordersForDay(_day);
  }

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

  void _moveDay(int days) {
    setState(() {
      _day = DateTime(_day.year, _day.month, _day.day + days);
      _load();
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _day = picked;
        _load();
      });
    }
  }

  Future<void> _print(DailySummary summary) async {
    if (_printing) return;
    setState(() => _printing = true);
    final printer = context.read<PrinterProvider>();
    final settings = context.read<SettingsProvider>();
    final r = await printer.printDailySummary(
      summary,
      settings.receiptSettings,
    );
    if (!mounted) return;
    setState(() => _printing = false);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary printed', style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.print_disabled, color: Colors.red, size: 40),
          title: const Text('Not printed'),
          content: Text(r.message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen(),
                  ),
                );
              },
              child: const Text('Connect ZYWELL'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final shared = context.watch<CafeProvider>().isShared;
    String money(int c) => formatMoney(c, currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily summary')),
      body: StreamBuilder<List<Order>>(
        stream: _stream,
        builder: (context, snap) {
          final orders = snap.data ?? const <Order>[];
          final s = DailySummary.fromOrders(_day, orders);
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              // Day picker
              Row(
                children: [
                  IconButton.filledTonal(
                    iconSize: 28,
                    onPressed: () => _moveDay(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _pickDay,
                      child: Text(
                        _isToday
                            ? 'Today, ${DateFormat('dd MMM yyyy').format(_day)}'
                            : DateFormat('EEE, dd MMM yyyy').format(_day),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    iconSize: 28,
                    onPressed: _isToday ? null : () => _moveDay(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (shared)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Includes orders from all cafe phones.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total sales',
                      value: money(s.totalCents),
                      big: true,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(label: 'Orders', value: '${s.orderCount}'),
                  ),
                  Expanded(
                    child: _StatCard(
                      label: 'Average order',
                      value: money(s.averageCents),
                    ),
                  ),
                ],
              ),
              if (s.orderCount == 0)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No orders on this day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                )
              else ...[
                _Section(
                  title: 'By payment',
                  children: [
                    for (final p in s.byPayment)
                      _Row('${p.label} (${p.count})', money(p.cents)),
                  ],
                ),
                _Section(
                  title: 'Best sellers',
                  children: [
                    for (final i in s.items)
                      _Row('${i.count} x ${i.label}', money(i.cents)),
                  ],
                ),
                if (s.byCashier.length > 1)
                  _Section(
                    title: 'By cashier',
                    children: [
                      for (final c in s.byCashier)
                        _Row('${c.label} (${c.count})', money(c.cents)),
                    ],
                  ),
                if (s.firstOrder != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'First order ${DateFormat('hh:mm a').format(s.firstOrder!)}'
                      ' · last ${DateFormat('hh:mm a').format(s.lastOrder!)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: _printing ? null : () => _print(s),
                icon: _printing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: Text(_printing ? 'Printing...' : 'Print summary'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  const _StatCard({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: big ? 32 : 22,
                fontWeight: FontWeight.bold,
                color: big ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
