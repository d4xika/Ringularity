import 'package:flutter/material.dart';
import 'package:ringularity/screens/auth/register_screen.dart';
import 'package:ringularity/widgets/common/big_button.dart';
import 'login_screen.dart';
import '../../theme/text_styles.dart';

class StartScreen extends StatefulWidget {
  final bool isOffline;

  const StartScreen({super.key, this.isOffline = false});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isOffline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You are offline!")));
        return;
      }
    });
  }

  void _navigateTo(Widget screen) {
    if (widget.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You are offline! Login/Register not available."),
        ),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

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

                Align(
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
                        _navigateTo(const LoginScreen());
                      },
                    ),

                    const SizedBox(height: 16),

                    BigButton(
                      child: const Text(
                        "Register",
                        style: AppTextStyles.buttonLabel,
                      ),
                      onPressed: () {
                        _navigateTo(const RegisterScreen());
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
