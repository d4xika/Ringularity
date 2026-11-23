import 'package:flutter/material.dart';

import '../../services/api/api_service.dart';

/// Confirms irreversible account deletion with the current account password.
class DeleteAccountScreen extends StatefulWidget {
  /// Creates the account deletion form.
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

/// Tracks password confirmation, request progress and retry feedback for account deletion.
class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _api = ApiService();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _api.dispose();
    super.dispose();
  }

  /// Keeps failed requests retryable and prevents duplicate submissions.
  Future<void> _delete() async {
    final password = _password.text;
    _password.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.deleteAccount(password);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Delete account')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This permanently deletes your account and all associated health and activity records from Ringularity’s database. Your cached profile, measurements, activities, goals, consent and login credentials will also be removed from this device.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Data stored on the ring, on other devices, in backups or in files you have already shared is not erased by this action. You can reset the ring separately under Device Management. This action cannot be undone.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _confirmed = value ?? false;
                          });
                        },
                  title: const Text(
                    'I understand that my account and its data will be permanently deleted.',
                  ),
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: _busy || !_confirmed || _password.text.isEmpty
                      ? null
                      : _delete,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Permanently delete account'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
