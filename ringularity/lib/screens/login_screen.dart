import 'package:flutter/material.dart';
import 'package:ringularity/screens/home_screen.dart';
import 'package:ringularity/widgets/big_button.dart';
import '../theme/text_styles.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                const Align(
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

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Login", style: AppTextStyles.subtitle),
                ),

                const Spacer(flex: 1),

                const Column(
                  children: [
                    CustomTextField(
                      label: "Email",
                      keyboardType: TextInputType.emailAddress,
                    ),

                    SizedBox(height: 20),

                    CustomTextField(label: "Password", isPassword: true),
                  ],
                ),

                const Spacer(flex: 2),

                BigButton(
                  child: const Text("Login", style: AppTextStyles.buttonLabel),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
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
