import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ringularity/services/api/api_service.dart';
import 'package:ringularity/services/secure_storage_service.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/big_button.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/custom_scrollbar.dart';
import 'package:intl/intl.dart';
import '../home/main_screen.dart';
import '../../services/api/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/starry_night_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Welcome!', style: AppTextStyles.title),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: Image.asset(
                    'assets/logo_transparent.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: CustomScrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(right: 18, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Register', style: AppTextStyles.subtitle),
                          const SizedBox(height: 20),

                          CustomTextField(
                            label: 'Name',
                            controller: _nameController,
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            label: 'Email',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),

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
                          const SizedBox(height: 20),

                          CustomTextField(
                            label: 'Password',
                            controller: _passwordController,
                            isPassword: true,
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            label: 'confirm Password',
                            controller: _confirmPasswordController,
                            isPassword: true,
                          ),
                          const SizedBox(height: 40),

                          BigButton(
                            child: const Text(
                              "Register",
                              style: AppTextStyles.buttonLabel,
                            ),
                            onPressed: () async {
                              if (_nameController.text.isEmpty ||
                                  _emailController.text.isEmpty ||
                                  _birthdateController.text.isEmpty ||
                                  _passwordController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please enter all your information",
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (_passwordController.text !=
                                  _confirmPasswordController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Passwords don't match!"),
                                  ),
                                );
                                return;
                              }

                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              final response = await _apiService.registerUser({
                                "name": _nameController.text,
                                "email": _emailController.text,
                                "birthdate": _birthdateController.text,
                                "password": _passwordController.text,
                              });

                              final Map<String, dynamic> responseData =
                                  jsonDecode(response.body);

                              if (response.statusCode > 300) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(responseData["error"]),
                                  ),
                                );
                                return;
                              }

                              StorageService.saveUserSession(
                                responseData["auth_key"],
                                responseData["user_id"].toString(),
                              );

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text("Successfully registered!"),
                                ),
                              );

                              navigator.pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const MainScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
