import 'package:flutter/material.dart';
import 'package:ringularity/screens/details/goals_screen.dart';
import '../../widgets/goals_activity/stat_card.dart';
import '../../widgets/goals_activity/activity_rings.dart';
import '../../widgets/goals_activity/battery_indicator.dart';
import '../../theme/text_styles.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome home,", style: AppTextStyles.subsubtitle),
                      Text("Gatja", style: AppTextStyles.title),
                    ],
                  ),
                  BatteryIndicator(percentage: 0.75),
                ],
              ),

              const Spacer(flex: 1),

              Flexible(
                flex: 8,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoalsScreen(),
                    ),
                  ),
                  child: const ActivityRingsCard(),
                ),
              ),

              const Spacer(flex: 1),

              Expanded(
                flex: 12,
                child: GridView.count(
                  physics: const BouncingScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
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
    );
  }
}
