import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/cafe_provider.dart';
import '../providers/settings_provider.dart';
import '../services/cloud_service.dart' show CloudException, CloudMessages;

/// Share the cafe with other phones (create), or show the cafe code.
class CafeSharingScreen extends StatefulWidget {
  const CafeSharingScreen({super.key});

  @override
  State<CafeSharingScreen> createState() => _CafeSharingScreenState();
}

class _CafeSharingScreenState extends State<CafeSharingScreen> {
  String? _progress; // non-null while creating
  String? _pin;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final cafe = context.read<CafeProvider>();
    if (!cafe.isShared) return;
    final pin = await cafe.readPin();
    if (mounted) setState(() => _pin = pin);
  }

  Future<void> _create() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _ChoosePinDialog(),
    );
    if (pin == null || !mounted) return;
    final cafe = context.read<CafeProvider>();
    setState(() => _progress = 'Connecting...');
    try {
      await cafe.createCafe(
        pin,
        onProgress: (step) {
          if (mounted) setState(() => _progress = step);
        },
      );
      if (!mounted) return;
      setState(() {
        _progress = null;
        _pin = pin;
      });
    } on CloudException catch (e) {
      if (!mounted) return;
      setState(() => _progress = null);
      _error(e.message);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop sharing on this phone?'),
        content: const Text(
          'This phone will stop seeing the shared menu and orders and go back '
          'to its own old data. The other phones are not affected. You can '
          'join again later with the cafe code and PIN.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop sharing'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<CafeProvider>().leaveCafe();
  }

  void _error(String msg) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Not done'),
      content: Text(msg, style: const TextStyle(fontSize: 16)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cafe = context.watch<CafeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Share with other phones')),
      body: _progress != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_progress!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Please keep the app open.'),
                ],
              ),
            )
          : !cafe.sharingAvailable
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                CloudMessages.notSetUp,
                style: TextStyle(fontSize: 18),
              ),
            )
          : cafe.isShared
          ? _sharedView(cafe)
          : _notSharedView(),
    );
  }

  Widget _notSharedView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Right now the menu and orders are only on this phone.',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This is the main phone',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Put this cafe online so other phones can use the same '
                  'menu, prices, logo and orders. Everything already on this '
                  'phone is copied up once (needs internet for that).',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Share this cafe'),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This is a staff phone',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join a cafe that is already shared, using its cafe code '
                  'and PIN.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinCafeScreen()),
                  ),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join my cafe'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sharedView(CafeProvider cafe) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.cloud_done, size: 48, color: Colors.green),
                const SizedBox(height: 8),
                const Text(
                  'This cafe is shared',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                const Text('Cafe code'),
                SelectableText(
                  cafe.cafeCode!,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
                if (_pin != null) ...[
                  const SizedBox(height: 8),
                  const Text('PIN'),
                  Text(
                    _pin!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Cafe code: ${cafe.cafeCode}'
                            '${_pin == null ? '' : '\nPIN: $_pin'}',
                      ),
                    );
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy code and PIN'),
                ),
                Text(
                  'This phone is "${cafe.deviceTag}" '
                  '(its order numbers start with ${cafe.deviceTag}).',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'To add a staff phone:\n'
              '1. Install the Take Orders app on it.\n'
              '2. On the first screen tap "Join my cafe".\n'
              '3. Type the cafe code and PIN above.\n\n'
              'Keep the PIN private: anyone with the code and PIN can see '
              'and change the menu and orders.\n\n'
              'Works without internet too: changes are sent when the phone '
              'is online again.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _leave,
          child: const Text('Stop sharing on this phone'),
        ),
      ],
    );
  }
}

class _ChoosePinDialog extends StatefulWidget {
  const _ChoosePinDialog();

  @override
  State<_ChoosePinDialog> createState() => _ChoosePinDialogState();
}

class _ChoosePinDialogState extends State<_ChoosePinDialog> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _ok() {
    final p = _pin1.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(p)) {
      setState(() => _error = 'Use 4 to 8 numbers');
    } else if (p != _pin2.text.trim()) {
      setState(() => _error = 'The two PINs are not the same');
    } else {
      Navigator.pop(context, p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose a cafe PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Staff will type this PIN once to join. Use 4 to 8 numbers.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin1,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, letterSpacing: 4),
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pin2,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, letterSpacing: 4),
            decoration: InputDecoration(
              labelText: 'PIN again',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Share')),
      ],
    );
  }
}

/// Staff phone: join a shared cafe with code + PIN.
class JoinCafeScreen extends StatefulWidget {
  const JoinCafeScreen({super.key});

  @override
  State<JoinCafeScreen> createState() => _JoinCafeScreenState();
}

class _JoinCafeScreenState extends State<JoinCafeScreen> {
  final _code = TextEditingController();
  final _pin = TextEditingController();
  late final TextEditingController _cashier;
  late int _paper;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _cashier = TextEditingController(text: s.setupDone ? s.cashier : '');
    _paper = s.paperMm;
  }

  @override
  void dispose() {
    _code.dispose();
    _pin.dispose();
    _cashier.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy) return;
    if (_code.text.trim().length < 6 || _pin.text.trim().isEmpty) {
      setState(() => _error = 'Please type the 6-letter cafe code and the PIN');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final cafe = context.read<CafeProvider>();
    final settings = context.read<SettingsProvider>();
    final navigator = Navigator.of(context);
    try {
      await cafe.joinCafe(_code.text, _pin.text);
      await settings.resetOrderCounter();
      await settings.saveDevice(
        cashierName: _cashier.text.trim().isEmpty ? 'Staff' : _cashier.text,
        paper: _paper,
      );
      navigator.popUntil((r) => r.isFirst);
    } on CloudException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Join my cafe')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Ask the cafe owner for the cafe code and PIN. They are on the '
              'owner\'s phone under Menu > Share with other phones.',
              style: TextStyle(fontSize: 16),
            ),
            gap,
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 24, letterSpacing: 4),
              decoration: const InputDecoration(labelText: 'Cafe code'),
            ),
            gap,
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(fontSize: 24, letterSpacing: 4),
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            gap,
            TextField(
              controller: _cashier,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Your name (printed as cashier)',
              ),
            ),
            gap,
            const Text(
              'What paper is in the ZYWELL used with this phone?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 80, label: Text('80mm')),
                ButtonSegment(value: 58, label: Text('58mm')),
              ],
              selected: {_paper},
              onSelectionChanged: (s) => setState(() => _paper = s.first),
            ),
            if (_error != null) ...[
              gap,
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _join,
              icon: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_busy ? 'Joining...' : 'Join'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Needs internet to join. After that the app also works offline.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
