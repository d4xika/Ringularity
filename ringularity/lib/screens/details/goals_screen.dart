import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/goals_activity/activity_rings.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/goals_activity/calendar_row.dart';
import '../../widgets/goals_activity/weekly_goal_card.dart';
import '../../widgets/common/big_button.dart';
import '../../widgets/goals_activity/add_edit_goal_dialog.dart';
import '../../theme/text_styles.dart';
import 'calendar_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});


  @override
  Widget build(BuildContext context) {

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('d MMM y').format(now);

    return Scaffold(
      extendBody: true,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: BigButton(
          child: const Icon(Icons.add, color: AppColors.mainColor, size: 32),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) => const AddEditGoalDialog(),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 1),

                ScreenHeader(
                  title: formattedDate,
                  actionWidget: IconButton(
                    icon: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalendarScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                const CalendarRow(),

                const Spacer(flex: 1),

                const Flexible(
                  flex: 10,
                  child: SizedBox(
                    width: double.infinity,
                    child: ActivityRingsCard(),
                  ),
                ),

                const Spacer(flex: 1),

                const Text("Weekly Goals", style: AppTextStyles.subtitle),

                const SizedBox(height: 12),

                const Flexible(
                  flex: 6,
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: WeeklyGoalCard(),
                  ),
                ),

                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
