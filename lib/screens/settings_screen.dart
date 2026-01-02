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
              'Local Authentication',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FutureBuilder<bool>(
            future: _canUseBiometric,
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Biometric authentication not available on this device'),
                );
              }

              return ListTile(
                title: const Text('Biometric Authentication'),
                subtitle: const Text('Use fingerprint or face recognition'),
                trailing: Switch(
                  value: _biometricEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final authenticated = await _biometricService.authenticate();
                      if (authenticated) {
                        await _biometricService.enableBiometric();
                        setState(() => _biometricEnabled = true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Biometric authentication enabled'),
                            ),
                          );
                        }
                      }
                    } else {
                      await _biometricService.disableBiometric();
                      setState(() => _biometricEnabled = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Biometric authentication disabled'),
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('PIN Authentication'),
            subtitle: const Text('Use a PIN code to authenticate'),
            trailing: Switch(
              value: _pinEnabled,
              onChanged: (value) async {
                if (value) {
                  _showPINDialog(context);
                } else {
                  await _biometricService.disablePIN();
                  await _biometricService.clearPIN();
                  setState(() {
                    _pinEnabled = false;
                    _pinValue = null;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PIN authentication disabled'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          if (_pinEnabled)
            ListTile(
              title: const Text('Change PIN'),
              subtitle: const Text('Update your authentication PIN'),
              onTap: () => _showPINDialog(context),
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
