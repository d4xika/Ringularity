import 'package:flutter/material.dart';
import 'package:ringularity/screens/goals_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/stat_card.dart';
import '../widgets/activity_rings.dart';
import '../widgets/battery_indicator.dart';
import '../widgets/buttom_navigation.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: const CustomNavBar(),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/starry_night_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.02),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome home,",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          "Gatja",
                          style: TextStyle(
                            color: AppColors.mainColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    BatteryIndicator(percentage: 0.75),
                  ],
                ),

                SizedBox(height: screenHeight * 0.03),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  GoalsScreen()),
                    );
                  },

                  child: SizedBox(
                    height: screenHeight * 0.30,
                    width: double.infinity,
                    child: const ActivityRingsCard(),
                  ),
                ),

                SizedBox(height: screenHeight * 0.03),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,

                    childAspectRatio: (screenWidth / 2) / (screenHeight * 0.22),

                    padding: const EdgeInsets.only(bottom: 100),
                    children: const [
                      StatCard(
                        icon: Icons.directions_run,
                        value: "2.069",
                        label: "Steps",
                      ),
                      StatCard(icon: Icons.favorite, value: "100", label: "HR"),
                      StatCard(
                        icon: Icons.nightlight_round,
                        value: "8h 10m",
                        label: "Sleep",
                      ),
                      StatCard(
                        icon: Icons.sentiment_satisfied,
                        value: "10",
                        label: "Stress",
                      ),
                      StatCard(
                        icon: Icons.water_drop,
                        value: "98%",
                        label: "Oxygen",
                      ),
                      StatCard(
                        icon: Icons.fitness_center,
                        value: "5.2km",
                        label: "Run",
                      ),
                    ],
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
