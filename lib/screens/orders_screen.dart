import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/order_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/money.dart';
import '../widgets/print_helper.dart';
import 'daily_summary_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final Set<String> _printing = {};

  Future<void> _reprint(Order order) async {
    if (_printing.contains(order.id)) return;
    setState(() => _printing.add(order.id!));
    await printOrderWithFeedback(context, order);
    if (mounted) setState(() => _printing.remove(order.id));
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final dayFmt = DateFormat('EEE, dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');

    final children = <Widget>[];
    String? lastDay;
    for (final o in orders.orders) {
      final day = dayFmt.format(o.createdAt);
      if (day != lastDay) {
        lastDay = day;
        final dayTotal = orders.orders
            .where((x) => dayFmt.format(x.createdAt) == day)
            .fold(0, (s, x) => s + x.totalCents);
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  formatMoney(dayTotal, currency),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final printing = _printing.contains(o.id);
      children.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ExpansionTile(
            title: Text(
              '${o.number}  ·  ${formatMoney(o.totalCents, currency)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${timeFmt.format(o.createdAt)} · ${o.itemCount} items · ${o.paymentMethod}',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              for (final i in o.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${i.qty} x ${i.name}${i.note.isEmpty ? '' : '\n   (${i.note})'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Text(
                        formatMoney(i.lineTotalCents, currency),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              if (o.cashGivenCents != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Cash ${formatMoney(o.cashGivenCents!, currency)} · '
                    'Change ${formatMoney(o.changeCents, currency)}',
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: printing ? null : () => _reprint(o),
                icon: printing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: const Text('Reprint'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'Daily summary',
            icon: const Icon(Icons.summarize),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DailySummaryScreen()),
            ),
          ),
        ],
      ),
      body: orders.orders.isEmpty
          ? const Center(
              child: Text('No orders yet', style: TextStyle(fontSize: 18)),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Last 30 days. Tap an order to see items or reprint.',
                  ),
                ),
                ...children,
              ],
            ),
    );
  }
}
