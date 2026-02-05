import 'package:flutter/material.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/big_button.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/custom_scrollbar.dart';
import 'package:intl/intl.dart';
import '../home/main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _birthdateController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
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
                const Align(
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
                          const Text('Register', style: AppTextStyles.subtitle),
                          const SizedBox(height: 20),

                          const CustomTextField(label: 'Name'),
                          const SizedBox(height: 20),

                          const CustomTextField(
                            label: 'Email',
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

                          const CustomTextField(
                            label: 'Password',
                            isPassword: true,
                          ),
                          const SizedBox(height: 20),

                          const CustomTextField(
                            label: 'confirm Password',
                            isPassword: true,
                          ),
                          const SizedBox(height: 40),

                          BigButton(
                            child: const Text(
                              "Register",
                              style: AppTextStyles.buttonLabel,
                            ),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
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
