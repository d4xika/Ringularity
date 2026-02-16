import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ringularity/screens/home/main_screen.dart';
import 'package:ringularity/services/api/api_service.dart';
import 'package:ringularity/widgets/common/big_button.dart';
import '../../theme/text_styles.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../services/secure_storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  child: Text("Welcome back!", style: AppTextStyles.title),
                ),

                const Spacer(flex: 1),

                Flexible(
                  flex: 4,
                  child: Image.asset(
                    'assets/logo_transparent.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const Spacer(flex: 1),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Login", style: AppTextStyles.subtitle),
                ),

                const Spacer(flex: 1),

                Column(
                  children: [
                    CustomTextField(
                      label: "Email",
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                    ),

                    const SizedBox(height: 20),

                    CustomTextField(
                      label: "Password",
                      isPassword: true,
                      controller: _passwordController,
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                BigButton(
                  child: const Text("Login", style: AppTextStyles.buttonLabel),
                  onPressed: () async {
                    if (_emailController.text.isEmpty ||
                        _passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please enter all your information!"),
                        ),
                      );
                      return;
                    }

                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    final response = await _apiService.loginUser({
                      "email": _emailController.text,
                      "password": _passwordController.text,
                    });

                    final Map<String, dynamic> responseData = jsonDecode(
                      response.body,
                    );

                    if (response.statusCode > 300) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(responseData["error"])),
                      );
                      return;
                    }

                    StorageService.saveUserSession(
                      responseData["auth_key"],
                      responseData["user_id"].toString(),
                    );

                    messenger.showSnackBar(
                      const SnackBar(content: Text("Successfully logged in!")),
                    );

                    navigator.pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(),
                      ),
                    );
                  },
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
