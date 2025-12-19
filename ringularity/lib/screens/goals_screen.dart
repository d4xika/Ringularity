import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_rings.dart';
import '../widgets/screen_header.dart';
import '../widgets/calendar_row.dart';
import '../widgets/weekly_goal_card.dart';
import '../widgets/subtitle.dart';
import '../widgets/bigbutton.dart';
import '../widgets/add_edit_goal_dialog.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true,
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: BigButton(
          child: const Icon(Icons.add, color: AppColors.mainColor, size: 32),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return const AddEditGoalDialog();
              },
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
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenSize.height * 0.02),

                ScreenHeader(
                  title: "Goals",
                  actionWidget: IconButton(
                    icon: const Icon(Icons.calendar_month_outlined,
                        color: AppColors.textPrimary),
                    onPressed: () {},
                  ),
                ),

                SizedBox(height: screenSize.height * 0.03),

                const CalendarRow(),

                SizedBox(height: screenSize.height * 0.03),

                SizedBox(
                  height: screenSize.height * 0.30,
                  width: double.infinity,
                  child: const ActivityRingsCard(),
                ),

                SizedBox(height: screenSize.height * 0.03),

                const Subtitle(text: "Weekly Goals"),

                SizedBox(height: screenSize.height * 0.02),

                const WeeklyGoalCard(),
                
                // Platzhalter unten
                const SizedBox(height: 80), 
              ],
            ),
          ),
        ),
      ),
    );
  }
}