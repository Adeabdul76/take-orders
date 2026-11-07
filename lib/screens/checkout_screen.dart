import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/money.dart';
import '../widgets/print_helper.dart';

const paymentMethods = ['Cash', 'DuitNow QR', 'Card', 'E-Wallet'];

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _method = 'Cash';
  final _cash = TextEditingController();
  bool _saving = false;
  bool _printing = false;
  Order? _saved;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  int? get _cashCents => parseMoneyToCents(_cash.text);

  Future<void> _confirm() async {
    if (_saving) return; // prevent double tap = double order
    final cart = context.read<CartProvider>();
    final total = cart.totalCents;
    int? cashGiven;
    if (_method == 'Cash') {
      cashGiven = _cash.text.trim().isEmpty ? total : _cashCents;
      if (cashGiven == null || cashGiven < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cash given is less than the total',
              style: TextStyle(fontSize: 16),
            ),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final settings = context.read<SettingsProvider>();
    final orders = context.read<OrderProvider>();
    final order = await cart.checkout(
      paymentMethod: _method,
      cashGivenCents: cashGiven,
      cashier: settings.cashier,
    );
    await orders.refreshToday();
    if (!mounted) return;
    setState(() {
      _saved = order;
      _saving = false;
    });
    if (settings.autoPrint) _print();
  }

  Future<void> _print() async {
    if (_printing || _saved == null) return;
    setState(() => _printing = true);
    await printOrderWithFeedback(context, _saved!);
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _saved == null ? 'Checkout' : 'Order ${_saved!.number} saved',
          ),
          automaticallyImplyLeading: _saved == null,
        ),
        body: SafeArea(
          child: _saved == null ? _paymentForm(currency) : _success(currency),
        ),
      ),
    );
  }

  Widget _paymentForm(String currency) {
    final cart = context.watch<CartProvider>();
    final total = cart.totalCents;
    final given = _cash.text.trim().isEmpty ? total : _cashCents;
    final change = given == null ? null : given - total;
    final quick = <int>{
      total,
      1000,
      2000,
      5000,
      10000,
    }.where((c) => c >= total).toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${cart.itemCount} items',
                  style: const TextStyle(fontSize: 18),
                ),
                const Spacer(),
                Text(
                  formatMoney(total, currency),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in paymentMethods)
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Text(m, style: const TextStyle(fontSize: 17)),
                ),
                selected: _method == m,
                onSelected: (_) => setState(() => _method = m),
              ),
          ],
        ),
        if (_method == 'Cash') ...[
          const SizedBox(height: 20),
          TextField(
            controller: _cash,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: 'Cash given ($currency)',
              hintText: 'Leave empty if exact',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in quick)
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _cash.text = (c / 100).toStringAsFixed(2)),
                  child: Text(c == total ? 'Exact' : formatMoney(c, currency)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Change', style: TextStyle(fontSize: 20)),
              const Spacer(),
              Text(
                change == null
                    ? '-'
                    : change < 0
                    ? 'Not enough'
                    : formatMoney(change, currency),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: (change ?? 0) < 0 ? Colors.red : Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          onPressed: _saving || cart.isEmpty ? null : _confirm,
          icon: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle),
          label: const Text('Confirm & save order'),
        ),
      ],
    );
  }

  Widget _success(String currency) {
    final order = _saved!;
    final printer = context.watch<PrinterProvider>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 96),
        const SizedBox(height: 8),
        Text(
          'Order ${order.number} saved',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Total ${formatMoney(order.totalCents, currency)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        if (order.cashGivenCents != null)
          Text(
            'Change ${formatMoney(order.changeCents, currency)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        const SizedBox(height: 32),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          onPressed: _printing ? null : _print,
          icon: _printing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print),
          label: Text(_printing ? 'Printing...' : 'Print Receipt with ZYWELL'),
        ),
        if (!printer.isConnected)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'ZYWELL not connected - you can reprint later from Orders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
          ),
          onPressed: _printing
              ? null
              : () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
