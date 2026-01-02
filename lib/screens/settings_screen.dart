import 'package:flutter/material.dart';
import '../services/biometric_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _biometricService = BiometricAuthService();
  late Future<bool> _canUseBiometric;
  bool _biometricEnabled = false;
  bool _pinEnabled = false;
  String? _pinValue;

  @override
  void initState() {
    super.initState();
    _canUseBiometric = _biometricService.canUseBiometric();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    final pinEnabled = await _biometricService.isPINEnabled();
    final pin = await _biometricService.getPIN();

    setState(() {
      _biometricEnabled = biometricEnabled;
      _pinEnabled = pinEnabled;
      _pinValue = pin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Authentication',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Change PIN'),
            subtitle: Text(_pinEnabled ? 'PIN authentication is active' : 'Set up your PIN'),
            leading: const Icon(Icons.lock_outline),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showPINDialog(context),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'PIN authentication is required for security. You will be asked to enter your PIN whenever the app is reopened or minimized.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPINDialog(BuildContext context) async {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set PIN'),
        content: TextField(
          controller: pinController,
          decoration: const InputDecoration(
            labelText: 'Enter a 4-6 digit PIN',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length < 4 || pin.length > 6) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN must be 4-6 digits'),
                    ),
                  );
                }
                return;
              }

              await _biometricService.savePIN(pin);
              await _biometricService.enablePIN();
              setState(() {
                _pinEnabled = true;
                _pinValue = pin;
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN authentication enabled'),
                  ),
                );
              }
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }
}
