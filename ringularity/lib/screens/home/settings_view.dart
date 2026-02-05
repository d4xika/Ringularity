import 'package:flutter/material.dart';
import 'package:ringularity/screens/auth/start_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/big_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/settings/device_card.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/frequency_picker.dart';
import '../../widgets/settings/add_device_card.dart';
import 'package:intl/intl.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isDeviceConnected = true;
  bool _notificationsEnabled = true;
  String _selectedFrequency = "30 min";
  final TextEditingController _birthdateController = TextEditingController();

  @override
  void dispose() {
    _birthdateController.dispose();
    super.dispose();
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
              const Text("Settings", style: AppTextStyles.title),
              const SizedBox(height: 30),

              _isDeviceConnected
                  ? DeviceCard(
                      deviceName: "COLMI R10_CF04",
                      batteryLevel: "69%",
                      onUnbind: () {
                        setState(() => _isDeviceConnected = false);
                      },
                      onEditFrequency: () => _showFrequencyPopup(),
                    )
                  : AddDeviceCard(
                      onTap: () {
                        setState(() => _isDeviceConnected = true);
                      },
                    ),

              const SizedBox(height: 30),

              _buildToggleRow(),

              const Divider(color: Colors.white10, height: 32),

              SettingsSection(
                title: "Health Details",
                children: [
                  const CustomTextField(label: "Weight (kg)"),
                  const SizedBox(height: 10),

                  const CustomTextField(label: "Height (cm)"),
                  _buildSaveButton(),
                ],
              ),

              SettingsSection(
                title: "Account Information",
                children: [
                  const CustomTextField(label: "Name"),
                  const SizedBox(height: 10),

                  const CustomTextField(
                    label: "Email Address",
                    keyboardType: TextInputType.emailAddress,
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

                  const CustomTextField(label: "Password", isPassword: true),
                  const SizedBox(height: 10),

                  const CustomTextField(
                    label: "confirm Password",
                    isPassword: true,
                  ),
                  const SizedBox(height: 10),
                  _buildSaveButton(),
                ],
              ),

              const SizedBox(height: 60),

              BigButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StartScreen(),
                    ),
                  );
                },
                child: const Text("Logout", style: AppTextStyles.buttonLabel),
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
        onPressed: () => FocusScope.of(context).unfocus(),
        child: const Text(
          "Save Changes",
          style: TextStyle(color: AppColors.mainColor),
        ),
      ),
    );
  }

  void _showFrequencyPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return FrequencyPicker(
          selectedValue: _selectedFrequency,
          onSelected: (newValue) {
            setState(() => _selectedFrequency = newValue);

            Future.delayed(const Duration(milliseconds: 200), () {
              if (!context.mounted) return;
              Navigator.pop(context);
            });
          },
        );
      },
    );
  }
}
