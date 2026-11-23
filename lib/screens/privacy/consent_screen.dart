import 'package:flutter/material.dart';

import '../../services/user/consent_service.dart';
import '../../services/user/storage_service.dart';
import '../../widgets/privacy/privacy_information.dart';

/// Displays privacy information and collects explicit consent before backend access.
///
/// Onboarding starts with an unticked checkbox. The settings variant displays the
/// acceptance date and offers withdrawal instead of requesting consent again.
class ConsentScreen extends StatefulWidget {
  /// Whether this screen manages an existing acceptance from the app settings.
  final bool manage;

  /// Creates either the onboarding screen or the existing-consent management view.
  const ConsentScreen({super.key, this.manage = false});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

/// Tracks the explicit checkbox choice and feedback while persisting the user decision.
class _ConsentScreenState extends State<ConsentScreen> {
  bool _checked = false;
  bool _busy = false;
  bool _declined = false;
  bool _saveFailed = false;

  /// Disables repeated actions while saving and displays failures if the screen remains mounted.
  Future<void> _save(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveFailed = true;
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
    final consent = ConsentService.instance;
    final acceptedAt = consent.acceptedAt;
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy and consent")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Consent to backend data processing",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Please decide whether Ringularity may send your data to its backend before using account and cloud features.",
                  ),
                  const SizedBox(height: 24),
                  const PrivacyInformation(),
                  const SizedBox(height: 24),
                  Text(
                    "Your choice",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Consent is voluntary. Without it, Ringularity does not contact its backend, including for registration, login or synchronization. Account and cloud features remain unavailable. You can withdraw consent at any time under Settings → Privacy and consent. Withdrawal stops future backend transfers; it does not delete data already stored in the backend.",
                  ),
                  const SizedBox(height: 24),
                  const Text('Text version: ${ConsentService.textVersion}'),
                  if (widget.manage && acceptedAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Consent given on {date}".replaceFirst(
                        '{date}',
                        MaterialLocalizations.of(
                          context,
                        ).formatFullDate(acceptedAt.toLocal()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      key: const ValueKey('withdraw-backend-consent'),
                      onPressed: _busy ? null : () => _save(consent.revoke),
                      child: const Text("Withdraw consent"),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const ValueKey('backend-consent-checkbox'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _checked,
                      onChanged: _busy
                          ? null
                          : (value) {
                              setState(() {
                                _checked = value ?? false;
                              });
                            },
                      title: const Text(
                        "I explicitly consent to the described transfer and processing of my account, health and activity data.",
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const ValueKey('accept-backend-consent'),
                      onPressed: !_checked || _busy
                          ? null
                          : () => _save(consent.accept),
                      child: const Text("Agree and continue"),
                    ),
                    TextButton(
                      key: const ValueKey('decline-backend-consent'),
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() {
                                _checked = false;
                                _declined = true;
                              });
                              await _save(consent.revoke);
                            },
                      child: const Text("Do not agree"),
                    ),
                    if (_declined)
                      const Text(
                        "You have not consented. Backend connections remain disabled. You can change your choice here.",
                      ),
                    if (StorageService.currentSession != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _save(StorageService.deleteAll),
                        child: const Text("Sign out on this device"),
                      ),
                  ],
                  if (_saveFailed)
                    const Text(
                      "Your choice could not be saved. Please try again.",
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
