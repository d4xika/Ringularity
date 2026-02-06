import 'package:flutter/material.dart';
import 'package:ringularity/screens/details/goals_screen.dart';
import '../../widgets/stat_cards/stat_card.dart';
import '../../widgets/goals_activity/activity_rings.dart';
import '../../widgets/goals_activity/battery_indicator.dart';
import '../../theme/text_styles.dart';
import '../home/history_screen.dart';

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
                  children: [
                    StatCard(
                      icon: Icons.directions_run,
                      value: "2.069",
                      label: "Steps",
                      onTap: () => _navigateToHistory(context, "Steps", "2.069", "steps"),
                    ),
                    StatCard(
                      icon: Icons.favorite,
                      value: "100",
                      label: "HR",
                      onTap: () => _navigateToHistory(context, "HR", "100", "bpm"),),
                    StatCard(
                      icon: Icons.nightlight_round,
                      value: "8h 10m",
                      label: "Sleep",
                      onTap: () => _navigateToHistory(context, "Sleep", "8h 10m", ""),
                    ),
                    StatCard(
                      icon: Icons.sentiment_satisfied,
                      value: "10",
                      label: "Stress",
                      onTap: () => _navigateToHistory(context, "Stress", "10", "score"),
                    ),
                    StatCard(
                      icon: Icons.water_drop,
                      value: "98%",
                      label: "Oxygen",
                      onTap: () => _navigateToHistory(context, "Oxygen", "98", "%"),
                    ),
                    StatCard(
                      icon: Icons.fitness_center,
                      value: "5.2km",
                      label: "Run",
                      onTap: () => _navigateToHistory(context, "Run", "5.2", "km"),
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
  void _navigateToHistory(BuildContext context, String title, String value, String unit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(
          title: title,
          currentValue: value,
          unit: unit,
        ),
      ),
    );
  }
}
