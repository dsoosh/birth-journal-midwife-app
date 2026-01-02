import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';

class PinEntryScreen extends StatefulWidget {
  final SecureStorageService storage;
  final VoidCallback onPinVerified;

  const PinEntryScreen({
    super.key,
    required this.storage,
    required this.onPinVerified,
  });

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final _pinController = TextEditingController();
  String? _errorMessage;
  bool _isVerifying = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final enteredPin = _pinController.text.trim();

    if (enteredPin.isEmpty) {
      setState(() => _errorMessage = 'Please enter your PIN');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final savedPin = await widget.storage.getPin();
    
    if (savedPin == null) {
      // No PIN set, allow access
      widget.onPinVerified();
      return;
    }

    if (enteredPin == savedPin) {
      // PIN correct, save session validity
      final validUntil = DateTime.now().add(const Duration(hours: 24));
      await widget.storage.saveSessionValidUntil(validUntil);
      widget.onPinVerified();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN';
        _isVerifying = false;
      });
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter PIN'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.indigo,
              ),
              const SizedBox(height: 32),
              const Text(
                'Enter your PIN to continue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '••••••',
                    errorText: _errorMessage,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyPin,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
