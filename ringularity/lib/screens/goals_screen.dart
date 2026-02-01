import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_rings.dart';
import '../widgets/screen_header.dart';
import '../widgets/calendar_row.dart';
import '../widgets/weekly_goal_card.dart';
import '../widgets/big_button.dart';
import '../widgets/add_edit_goal_dialog.dart';
import '../theme/text_styles.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  title: "Goals",
                  actionWidget: IconButton(
                    icon: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {},
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
