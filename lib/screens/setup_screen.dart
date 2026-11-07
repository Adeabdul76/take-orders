import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// First-run setup (also opened later from the menu to edit shop details).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _cashier;
  late final TextEditingController _footer;
  late String _currency;
  late int _paper;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _name = TextEditingController(text: s.shopName);
    _phone = TextEditingController(text: s.shopPhone);
    _address = TextEditingController(text: s.shopAddress);
    _cashier = TextEditingController(text: s.cashier);
    _footer = TextEditingController(text: s.footer);
    _currency = s.currency;
    _paper = s.paperMm;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _cashier, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final settings = context.read<SettingsProvider>();
    final wasSetup = settings.setupDone;
    await settings.saveShop(
      name: _name.text,
      phone: _phone.text,
      address: _address.text,
      cashierName: _cashier.text,
      currencyCode: _currency,
      paper: _paper,
      footerText: _footer.text,
    );
    if (!mounted) return;
    if (wasSetup && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // On first run, the app switches to the Home screen automatically.
  }

  @override
  Widget build(BuildContext context) {
    final firstRun = !context.read<SettingsProvider>().setupDone;
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(
        title: Text(firstRun ? 'Welcome! Set up your shop' : 'Shop settings'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (firstRun)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'These details print at the top of every receipt. '
                    'You can change them later.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Shop name *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please type your shop name'
                    : null,
              ),
              gap,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
              ),
              gap,
              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                ),
              ),
              gap,
              TextFormField(
                controller: _cashier,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Cashier name on receipt',
                ),
              ),
              gap,
              const Text(
                'Currency on receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'RM', label: Text('RM')),
                  ButtonSegment(value: 'MYR', label: Text('MYR')),
                ],
                selected: {_currency},
                onSelectionChanged: (s) => setState(() => _currency = s.first),
              ),
              gap,
              const Text(
                'What paper is in your ZYWELL now? 80mm or 58mm?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 80, label: Text('80mm (wide)')),
                  ButtonSegment(value: 58, label: Text('58mm (narrow)')),
                ],
                selected: {_paper},
                onSelectionChanged: (s) => setState(() => _paper = s.first),
              ),
              gap,
              TextFormField(
                controller: _footer,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Receipt footer message',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(firstRun ? 'Start taking orders' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
