import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/screens/details/goals_screen.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import '../../widgets/stat_cards/stat_card.dart';
import '../../widgets/goals_activity/activity_rings.dart';
import '../../widgets/goals_activity/battery_indicator.dart';
import '../../theme/text_styles.dart';
import '../home/history_screen.dart';
import '../../widgets/common/custom_scrollbar.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  //TODO: DONE add real data from the ring
  //TODO: add the current date on the dashboard and add a function that you can quickly switch between the dates
  //TODO: in steps,HR... change put the date above the diagram
  //
  final ScrollController _gridScrollController = ScrollController();

  @override
  void dispose() {
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, service, child) {
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
              child: RefreshIndicator(
                onRefresh: () async {
                  await service.triggerSmartSync(force: true);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 1),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome home,",
                              style: AppTextStyles.subsubtitle,
                            ),
                            Text("Gatja", style: AppTextStyles.title),
                          ],
                        ),
                        Row(
                          children: [
                            if (service.isSyncing)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.cloud_upload,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                service.syncToCloud();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Uploading to cloud..."),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cloud_download,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                service.downloadFromCloud();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Downloading from cloud..."),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            BatteryIndicator(
                              percentage: service.batteryLevel / 100.0,
                              isConnected: service.isConnected,
                            ),
                          ],
                        ),
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
                      child: CustomScrollbar(
                        controller: _gridScrollController,
                        child: GridView.count(
                          controller: _gridScrollController,
                          physics: const BouncingScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          padding: const EdgeInsets.only(
                            bottom: 100,
                            right: 20,
                          ),
                          children: [
                            StatCard(
                              icon: Icons.directions_run,
                              value: service.steps.toString(),
                              label: "Steps",
                              onTap: () => _navigateToHistory(
                                context,
                                "Steps",
                                service.steps.toString(),
                                "steps",
                              ),
                            ),
                            StatCard(
                              icon: Icons.favorite,
                              value: service.heartRate.toString(),
                              label: "HR",
                              onTap: () => _navigateToHistory(
                                context,
                                "HR",
                                service.heartRate.toString(),
                                "bpm",
                              ),
                            ),
                            StatCard(
                              icon: Icons.nightlight_round,
                              value: service.totalSleepTimeFormatted,
                              label: "Sleep",
                              onTap: () => _navigateToHistory(
                                context,
                                "Sleep",
                                service.totalSleepTimeFormatted,
                                "",
                              ),
                            ),
                            StatCard(
                              icon: Icons.sentiment_satisfied,
                              value: service.stress.toString(),
                              label: "Stress",
                              onTap: () => _navigateToHistory(
                                context,
                                "Stress",
                                service.stress.toString(),
                                "score",
                              ),
                            ),
                            StatCard(
                              icon: Icons.water_drop,
                              value: "${service.spo2}%",
                              label: "Oxygen",
                              onTap: () => _navigateToHistory(
                                context,
                                "Oxygen",
                                service.spo2.toString(),
                                "%",
                              ),
                            ),
                            StatCard(
                              icon: Icons.route,
                              value:
                                  "${(service.distance / 1000).toStringAsFixed(2)}km",
                              label: "Distance",
                              onTap: () => _navigateToHistory(
                                context,
                                "Distance",
                                (service.distance / 1000).toStringAsFixed(2),
                                "km",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToHistory(
    BuildContext context,
    String title,
    String value,
    String unit,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HistoryScreen(title: title, currentValue: value, unit: unit),
      ),
    );
  }
}
