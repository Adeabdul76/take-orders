import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/shop_settings.dart';
import '../providers/cafe_provider.dart';
import '../providers/settings_provider.dart';
import '../services/zywell_printer_service.dart' show logoPrintPreview;
import '../utils/image_tools.dart';
import 'cafe_sharing_screen.dart';

/// First-run setup, and later "Shop settings" from the menu.
/// Shop details + logo are shared by all phones of the cafe;
/// cashier name and paper size belong to this phone only.
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
  String? _logoPng; // base64
  Uint8List? _logoPreview; // how it will print
  bool _logoBusy = false;
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
    _logoPng = s.shop.logoPng;
    _updatePreview();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _cashier, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  void _updatePreview() {
    if (_logoPng == null) {
      _logoPreview = null;
      return;
    }
    try {
      _logoPreview = logoPrintPreview(base64Decode(_logoPng!), _paper);
    } catch (_) {
      _logoPreview = null;
    }
  }

  Future<void> _pickLogo() async {
    setState(() => _logoBusy = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final prepared = await compute(prepareLogo, await picked.readAsBytes());
        if (prepared == null) throw Exception('not a picture');
        _logoPng = base64Encode(prepared);
        _updatePreview();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open that picture. Please try another one.',
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _logoBusy = false);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final settings = context.read<SettingsProvider>();
    final wasSetup = settings.setupDone;
    await settings.saveShop(
      ShopSettings(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        currency: _currency,
        footer: _footer.text.trim().isEmpty
            ? 'Thank you! Come again!'
            : _footer.text.trim(),
        logoPng: _logoPng,
      ),
    );
    await settings.saveDevice(cashierName: _cashier.text, paper: _paper);
    if (!mounted) return;
    if (wasSetup && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // On first run, the app switches to the Home screen automatically.
  }

  @override
  Widget build(BuildContext context) {
    final firstRun = !context.read<SettingsProvider>().setupDone;
    final cafe = context.watch<CafeProvider>();
    const gap = SizedBox(height: 16);
    const heading = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

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
              if (firstRun && cafe.sharingAvailable)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Is this a staff phone?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'If your cafe already uses this app on another '
                          'phone, join it and the menu appears here '
                          'automatically.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const JoinCafeScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.group_add),
                          label: const Text('Join my cafe'),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'First phone of the cafe? Fill in the form below.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (firstRun)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'These details print at the top of every receipt. '
                    'You can change them later.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              if (cafe.isShared)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Shop details and logo are shared: changes here show on '
                    'all cafe phones.',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              gap,
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

              // ---------- Logo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Receipt logo (optional)', style: heading),
                      const SizedBox(height: 4),
                      const Text(
                        'Prints at the top of every receipt, in black and '
                        'white. When a logo is set, the shop name is not '
                        'printed again as text.',
                      ),
                      const SizedBox(height: 12),
                      if (_logoBusy)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_logoPreview != null)
                        Center(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(8),
                            child: Image.memory(
                              _logoPreview!,
                              height: 160,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                        ),
                      if (_logoPreview != null && !_logoBusy)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'This is how it will print.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _logoBusy ? null : _pickLogo,
                              icon: const Icon(Icons.image),
                              label: Text(
                                _logoPng == null ? 'Choose logo' : 'Change',
                              ),
                            ),
                          ),
                          if (_logoPng != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () => setState(() {
                                  _logoPng = null;
                                  _logoPreview = null;
                                }),
                                child: const Text('Remove'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              gap,
              const Text('Currency on receipt', style: heading),
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
              TextFormField(
                controller: _footer,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Receipt footer message',
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text('This phone', style: heading),
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
                'What paper is in your ZYWELL now? 80mm or 58mm?',
                style: heading,
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 80, label: Text('80mm (wide)')),
                  ButtonSegment(value: 58, label: Text('58mm (narrow)')),
                ],
                selected: {_paper},
                onSelectionChanged: (s) => setState(() {
                  _paper = s.first;
                  _updatePreview();
                }),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving || _logoBusy ? null : _save,
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
