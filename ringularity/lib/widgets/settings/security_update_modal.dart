import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';
import '../../../services/api/api_service.dart';
import '../common/custom_text_field.dart';
import '../common/big_button.dart';

class SecurityUpdateModal extends StatefulWidget {
  final ApiService apiService;

  const SecurityUpdateModal({super.key, required this.apiService});

  static Future<void> show(BuildContext context, ApiService apiService) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SecurityUpdateModal(apiService: apiService),
    );
  }

  @override
  State<SecurityUpdateModal> createState() => _SecurityUpdateModalState();
}

class _SecurityUpdateModalState extends State<SecurityUpdateModal> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newFieldController = TextEditingController();

  bool _isPasswordVerified = false;
  String _updateType = "email";
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newFieldController.dispose();
    super.dispose();
  }

  // Lösung des Type-Mismatch: Wir rufen die async Funktion in einer synchronen Hülle auf
  void _onButtonPressed() {
    _handleAction();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Text(
            _isPasswordVerified ? "Update Credentials" : "Security Check",
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 10),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Text(
            _isPasswordVerified
                ? "Choose what you want to change."
                : "Verify your identity with your current password.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodywhite,
          ),
          const SizedBox(height: 25),

          if (!_isPasswordVerified) ...[
            CustomTextField(
              label: "Current Password",
              isPassword: true,
              controller: _currentPasswordController,
            ),
          ] else ...[
            Row(
              children: [
                _buildTypeChip("Email", "email"),
                const SizedBox(width: 10),
                _buildTypeChip("Password", "password"),
              ],
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: _updateType == "email" ? "New Email" : "New Password",
              isPassword: _updateType == "password",
              keyboardType: _updateType == "email"
                  ? TextInputType.emailAddress
                  : TextInputType.text,
              controller: _newFieldController,
            ),
          ],

          const SizedBox(height: 30),

          BigButton(
            // onPressed darf nicht async sein, also rufen wir unsere Wrapper-Funktion auf
            onPressed: _isLoading ? () {} : _onButtonPressed,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isPasswordVerified ? "Save Changes" : "Next Step",
                    style: AppTextStyles.bodywhite,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String type) {
    final isSelected = _updateType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _updateType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.mainColor : Colors.grey,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction() async {
    setState(() => _errorMessage = null);

    if (!_isPasswordVerified) {
      if (_currentPasswordController.text.isEmpty) {
        setState(() => _errorMessage = "Please enter your password.");
        return;
      }
      setState(() => _isPasswordVerified = true);
    } else {
      if (_newFieldController.text.isEmpty) {
        setState(() => _errorMessage = "Field cannot be empty.");
        return;
      }

      setState(() => _isLoading = true);

      final result = await widget.apiService.updateSecurity(
        currentPassword: _currentPasswordController.text,
        newEmail: _updateType == "email" ? _newFieldController.text : null,
        newPassword: _updateType == "password"
            ? _newFieldController.text
            : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result["success"]) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Security updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = result["error"];
          _isPasswordVerified = false; // Zurück zum Anfang bei Fehlern
          _currentPasswordController.clear();
        });
      }
    }
  }
}
