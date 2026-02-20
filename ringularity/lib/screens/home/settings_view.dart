import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ringularity/screens/auth/start_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ringularity/services/api/api_service.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/ble/packet_factory.dart';
import 'package:ringularity/services/storage_service.dart';
import 'package:ringularity/widgets/settings/security_update_modal.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/big_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/settings/device_card.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/monitoring_settings_sheet.dart';
import '../../widgets/settings/add_device_card.dart';
import 'package:ringularity/screens/home/api_debug_screen.dart';
import 'package:intl/intl.dart';

//TODO: maybe add device ID somewhere (maybe in debug view)?

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final BleService _bleService = BleService();
  bool _notificationsEnabled = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();

  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  @override
  void initState() {
    super.initState();
    _fillUserData();
    _bleService.addListener(_onBleUpdate);
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleUpdate);
    _nameController.dispose();
    _emailController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  Future<void> _fillUserData() async {
    // 2. User aus dem Storage holen
    final user = await StorageService.getUserProfile();

    if (user != null) {
      setState(() {
        _nameController.text = user.name;
        _emailController.text = user.email;
        _birthdateController.text = DateFormat(
          'dd.MM.yyyy',
        ).format(user.birthday);
        ;
      });
    }
  }

  void _onBleUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.mainColor,
              onPrimary: Colors.black,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Try to find a name, fallback to ID, fallback to "Unknown Device"
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
                        // await _bleService.disconnect(); // Handled in unpairRing
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

                  CustomTextField(
                    label: 'Birthdate',
                    controller: _birthdateController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 10),

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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
                    title: const Text(
                      "Factory Reset",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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

              SettingsSection(
                title: "Debug",
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      "Show API Data",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.data_object,
                      color: AppColors.mainColor,
                    ),
                    onTap: () => _showApiDataDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              BigButton(
                child: const Text("Logout", style: AppTextStyles.buttonLabel),
                onPressed: () async {
                  await _bleService.unpairRing();
                  await StorageService.deleteAll();
                  final alive = await _apiService.checkIfAlive();

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StartScreen(isOffline: !alive),
                    ),
                  );
                },
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Notifications", style: AppTextStyles.subsubtitle),
        Switch(
          value: _notificationsEnabled,
          onChanged: (val) => setState(() => _notificationsEnabled = val),
          inactiveTrackColor: AppColors.background,
          inactiveThumbColor: AppColors.background.withValues(alpha: 0.8),
          activeThumbColor: AppColors.mainColor,
        ),
      ],
    );
  }

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
          final success = await _apiService.updateUser(
            _nameController.text,
            _birthdateController.text,
          );

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile updated successfully!")),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Update failed. Please try again.")),
            );
          }
        },
      ),
    );
  }

  void _showMonitoringSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true, // Allow it to take more height if needed
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

  void _showScanningSheet() async {
    print("SettingsView: Preparing to scan...");
    await _bleService.unpairRing();

    print("SettingsView: Starting scan via service...");
    _bleService.startScan();

    if (!mounted) {
      print("SettingsView: Not mounted after unpair, aborting sheet.");
      return;
    }

    print("SettingsView: Showing ModalBottomSheet...");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        print("SettingsView: Building Sheet Content");
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return AnimatedBuilder(
              animation: _bleService,
              builder: (context, child) {
                final results = _bleService.scanResults;
                print(
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
                          final result = results[index];
                          final name = result.device.platformName.isNotEmpty
                              ? result.device.platformName
                              : "Unknown Device";
                          final id = result.device.remoteId.toString();
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
                              onPressed: () {
                                _bleService.connectToDevice(result.device);
                                _bleService.stopScan();
                                Navigator.pop(context);
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
    ).whenComplete(() {
      print("SettingsView: Sheet closed (whenComplete)");
      // _bleService.stopScan(); // DEBUG: Commented out to see if scan persists
    });
  }

  void _showRebootConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text("Reboot Device", style: AppTextStyles.subtitle),
        content: const Text(
          "Are you sure you want to reboot the ring?",
          style: AppTextStyles.bodywhite,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _bleService.sendRawPacket(PacketFactory.reboot());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Reboot command sent")),
              );
            },
            child: const Text(
              "Reboot",
              style: TextStyle(color: AppColors.mainColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showFactoryResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          "Factory Reset",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "WARNING: This will erase all data on the ring and reset it to factory settings. This action cannot be undone.",
          style: AppTextStyles.bodywhite,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _bleService.sendRawPacket(
                PacketFactory.createFactoryResetPacket(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Factory Reset command sent"),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text(
              "Reset",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showApiDataDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApiDebugScreen()),
    );
  }
}
