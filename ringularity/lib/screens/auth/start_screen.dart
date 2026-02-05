import 'package:flutter/material.dart';
import 'package:ringularity/screens/auth/register_screen.dart';
import 'package:ringularity/widgets/common/big_button.dart';
import 'login_screen.dart';
import '../../theme/text_styles.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
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
                const Spacer(flex: 1),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Hello stranger!", style: AppTextStyles.title),
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

                Column(
                  children: [
                    BigButton(
                      child: const Text(
                        "Login",
                        style: AppTextStyles.buttonLabel,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    BigButton(
                      child: const Text(
                        "Register",
                        style: AppTextStyles.buttonLabel,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                    ),
                  ],
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
