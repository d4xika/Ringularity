import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import '../privacy/consent_screen.dart';
import '../privacy/delete_account_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ringularity/screens/auth/start_screen.dart';
import 'package:ringularity/services/api/api_service.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/ble/packet_factory.dart';
import 'package:ringularity/services/notifications_service.dart';
import 'package:ringularity/services/user/storage_service.dart';
import 'package:ringularity/widgets/common/delete_conformation_sheet.dart';
import 'package:ringularity/widgets/settings/security_update_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/big_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/settings/add_device_card.dart';
import '../../widgets/settings/device_card.dart';
import '../../widgets/settings/monitoring_settings_sheet.dart';
import '../../widgets/settings/settings_section.dart';

/// A configuration interface for managing user profile details, application preferences, and hardware states.
///
/// Allows the user to:
/// - Connect/Disconnect/Reset the BLE Ring hardware.
/// - Adjust background measurement intervals (HR, HRV, Stress).
/// - Update their personal profile data and request data exports.
/// - Toggle local push notifications.
class SettingsView extends StatefulWidget {
  /// Creates a new [SettingsView] instance.
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

/// Manages account settings, privacy actions, exports and ring controls.
class _SettingsViewState extends State<SettingsView> {
  final BleService _bleService = BleService();
  bool _notificationsEnabled = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final ApiService _apiService = ApiService();

  /// Exposes the internal API service layer.
  ApiService get apiService => _apiService;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fillUserData();
    _bleService.addListener(_onBleUpdate);
    _loadNotificationStatus();
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleUpdate);
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Retrieves cached user session details to pre-fill the configuration fields.
  Future<void> _fillUserData() async {
    final version = StorageService.revision;
    final user = await StorageService.getUserProfile();
    if (!mounted || version != StorageService.revision) {
      return;
    }

    if (user != null) {
      setState(() {
        _nameController.text = user.name;
        _emailController.text = user.email;
      });
    }
  }

  /// Rebuilds the UI dynamically as the underlying BLE connection state fluctuates.
  void _onBleUpdate() {
    if (mounted) setState(() {});
  }

  /// Loads the persisted boolean flag dictating whether push notifications should fire.
  Future<void> _loadNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    String deviceName = "Unknown Device";
    if (_bleService.isConnected) {
      if (_bleService.currentDeviceName != null &&
          _bleService.currentDeviceName!.isNotEmpty) {
        deviceName = _bleService.currentDeviceName!;
      } else {
        final deviceId = _bleService.currentDeviceId;
        if (deviceId != null) {
          try {
            final device = _bleService.bondedDevices.firstWhere(
              (d) => d.remoteId.toString() == deviceId,
            );
            deviceName = device.platformName.isNotEmpty
                ? device.platformName
                : device.remoteId.toString();
          } catch (_) {
            deviceName = deviceId;
          }
        }
      }
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/starry_night_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Settings", style: AppTextStyles.title),
              const SizedBox(height: 30),

              _bleService.isConnected
                  ? DeviceCard(
                      deviceName: deviceName,
                      batteryLevel: "${_bleService.batteryLevel}%",
                      onUnbind: () async {
                        await _bleService.unpairRing();
                      },
                      onEditFrequency: () => _showMonitoringSettings(),
                    )
                  : _bleService.adapterState == BluetoothAdapterState.off
                  ? AddDeviceCard(
                      title: "Turn On Bluetooth",
                      icon: Icons.bluetooth_disabled_rounded,
                      onTap: () {
                        _bleService.turnOnBluetooth();
                      },
                    )
                  : _bleService.isConnecting
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.mainColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Connecting to ${_bleService.status.replaceAll('Connecting to ', '')}...",
                            style: AppTextStyles.bodywhite,
                          ),
                        ],
                      ),
                    )
                  : AddDeviceCard(
                      onTap: () {
                        _showScanningSheet();
                      },
                    ),

              const SizedBox(height: 30),

              _buildToggleRow(),

              const Divider(color: Colors.white10, height: 32),

              SettingsSection(
                title: "Privacy and consent",
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ConsentScreen(manage: true),
                        ),
                      );
                    },
                    child: const Text("View privacy information and consent"),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SettingsSection(
                title: "Account Information",
                children: [
                  CustomTextField(
                    label: "Name",
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                    ],
                  ),
                  const SizedBox(height: 10),

                  BigButton(
                    child: const Text(
                      "Change Login Data",
                      style: AppTextStyles.bodywhite,
                    ),
                    onPressed: () {
                      SecurityUpdateModal.show(context, _apiService);
                    },
                  ),
                  _buildSaveButton(),
                ],
              ),

              SettingsSection(
                title: "Device Management",
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      "Reboot Device",
                      style: AppTextStyles.bodywhite,
                    ),
                    trailing: const Icon(
                      Icons.restart_alt,
                      color: AppColors.mainColor,
                    ),
                    onTap: () => _showRebootConfirmation(),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      "Factory Reset",
                      style: AppTextStyles.bodywhite.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    onTap: () => _showFactoryResetConfirmation(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              BigButton(
                onPressed: _isExporting ? () {} : _startExportFlow,
                child: _isExporting
                    ? const CircularProgressIndicator()
                    : const Text(
                        "Export Data",
                        style: AppTextStyles.buttonLabel,
                      ),
              ),

              const SizedBox(height: 20),

              BigButton(
                child: const Text("Logout", style: AppTextStyles.buttonLabel),
                onPressed: () async {
                  await StorageService.deleteAll();
                  await _bleService.disconnect();
                  final alive = await _apiService.checkIfAlive();

                  if (!context.mounted) return;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StartScreen(isOffline: !alive),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DeleteAccountScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                label: const Text(
                  'Delete account',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a switch that persistently enables or revokes permission for scheduled push notifications.
  Widget _buildToggleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Notifications", style: AppTextStyles.subsubtitle),
        Switch(
          value: _notificationsEnabled,
          onChanged: (val) async {
            setState(() => _notificationsEnabled = val);

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notifications_enabled', val);

            if (!val) {
              await AwesomeNotifications().cancelAllSchedules();
            } else {
              await NotificationService.updateAllSchedules();
            }
          },
          inactiveTrackColor: AppColors.background,
          inactiveThumbColor: AppColors.background.withValues(alpha: 0.8),
          activeThumbColor: AppColors.mainColor,
        ),
      ],
    );
  }

  /// Builds a text button that saves the user's name through the backend API.
  Widget _buildSaveButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        child: const Text(
          "Save Changes",
          style: TextStyle(color: AppColors.mainColor),
        ),
        onPressed: () async {
          FocusScope.of(context).unfocus();
          final messenger = ScaffoldMessenger.of(context);

          final success = await _apiService.updateUser(_nameController.text);

          if (success) {
            messenger.showSnackBar(
              const SnackBar(content: Text("Profile updated successfully!")),
            );
          } else {
            messenger.showSnackBar(
              const SnackBar(content: Text("Update failed. Please try again.")),
            );
          }
        },
      ),
    );
  }

  /// Spawns a bottom sheet granting granular control over the background scanning intervals (HR, HRV, Stress) of the ring.
  void _showMonitoringSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return const MonitoringSettingsSheet();
          },
        );
      },
    );
  }

  /// Triggers a BLE proximity scan and exposes a modal displaying all available nearby hardware.
  void _showScanningSheet() async {
    final owner = StorageService.requireSession();
    await _bleService.stopScan();
    if (!owner.isCurrent || !mounted) {
      return;
    }
    try {
      await _bleService.startScan();
    } on SessionExpired {
      return;
    }

    if (!mounted || !owner.isCurrent) {
      debugPrint("SettingsView: Scan view no longer active.");
      return;
    }

    debugPrint("SettingsView: Showing ModalBottomSheet...");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        debugPrint("SettingsView: Building Sheet Content");
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return AnimatedBuilder(
              animation: _bleService,
              builder: (context, child) {
                final results = _bleService.availableDevices;
                debugPrint(
                  "SettingsView: Rebuilding list with ${results.length} devices",
                );
                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Text("Select Device", style: AppTextStyles.subtitle),
                    const SizedBox(height: 20),
                    if (_bleService.isScanning)
                      const LinearProgressIndicator(
                        color: AppColors.mainColor,
                        backgroundColor: Colors.white10,
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final device = results[index];
                          final name = device.platformName.isNotEmpty
                              ? device.platformName
                              : device.advName.isNotEmpty
                              ? device.advName
                              : "Unknown Device";
                          final id = device.remoteId.toString();
                          return ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              id,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mainColor,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () async {
                                await _bleService.stopScan();
                                if (!owner.isCurrent || !context.mounted) {
                                  return;
                                }
                                Navigator.pop(context);
                                await _bleService.connectToDevice(device);
                              },
                              child: const Text("Connect"),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).whenComplete(() async {
      if (owner.isCurrent) {
        await _bleService.stopScan();
      }
    });
  }

  /// Triggers an immediate soft restart of the connected BLE peripheral hardware.
  void _showRebootConfirmation() {
    ConfirmationSheet.show(
      context: context,
      title: "Reboot Device",
      message: "Are you sure you want to reboot the ring?",
      confirmLabel: "Reboot",
      confirmButtonColor: AppColors.mainColor,
      onConfirm: () {
        _bleService.sendRawPacket(PacketFactory.reboot());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Reboot command sent")));
      },
    );
  }

  /// Instructs the connected BLE peripheral to wipe all local storage and revert to factory conditions.
  void _showFactoryResetConfirmation() {
    ConfirmationSheet.show(
      context: context,
      title: "Factory Reset",
      isTitleDanger: true,
      message:
          "WARNING: This will erase all data on the ring. This action cannot be undone.",
      confirmLabel: "Reset Now",
      confirmButtonColor: Colors.red,
      onConfirm: () {
        _bleService.sendRawPacket(PacketFactory.createFactoryResetPacket());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Factory Reset command sent"),
            backgroundColor: Colors.redAccent,
          ),
        );
      },
    );
  }

  /// Requests the backend to generate a JSON export containing all historical data linked to the current user.
  void _startExportFlow() {
    if (_isExporting) return;

    ConfirmationSheet.show(
      context: context,
      title: "Export data",
      message: "Do you want to export all your data?",
      confirmLabel: "Export",
      confirmButtonColor: AppColors.mainColor,
      onConfirm: () async {
        setState(() => _isExporting = true);
        try {
          await _apiService.exportAllUserData();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        } finally {
          if (mounted) setState(() => _isExporting = false);
        }
      },
    );
  }
}
