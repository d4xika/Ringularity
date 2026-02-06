import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ringularity/theme/text_styles.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/stat_cards/scrubbable_chart.dart'; 
import '../../widgets/stat_cards/time_period_selector.dart';
import '../../widgets/stat_cards/stat_summary_header.dart';

class HistoryScreen extends StatefulWidget {
  final String title;
  final String currentValue;
  final String unit;

  const HistoryScreen({
    super.key,
    required this.title,
    required this.currentValue,
    this.unit = "",
  });
  

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedPeriod = "D";
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    const Color themeColor = AppColors.accentBlue;
    const cumulativeTypes = ["Steps", "Sleep", "Activity", "Run"];

    bool showTotal = false;
    if (_selectedPeriod == "D" && cumulativeTypes.contains(widget.title)) {
      showTotal = true;
    }

    // Welcher Wert soll angezeigt werden? (Mock Logik)
    String displayValue = _selectedPeriod == "D" 
        ? widget.currentValue 
        : _getMockValue(widget.title);

    final List<double> chartData = _generateDataPoints();
    final double dynamicMaxY = _calculateMaxY(chartData);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ScreenHeader(title: widget.title),
            ),

            // --- 2. TABS (Ausgelagert) ---
            TimePeriodSelector(
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: (newPeriod) {
                setState(() {
                  _selectedPeriod = newPeriod;
                });
              },
            ),

            const SizedBox(height: 20),

            // --- 3. WERT & KALENDER (Ausgelagert) ---
            StatSummaryHeader(
              isTotal: showTotal,
              value: displayValue,
              unit: widget.unit,
              valueColor: AppColors.mainColor,
              onCalendarTap: () => _showCalendarPicker(context),
            ),

            const SizedBox(height: 20),

            // --- 4. CHART BEREICH ---
            Expanded(
              child: ScrubbableChart(
                // Hier übergeben wir das dynamisch berechnete Maximum
                maxY: dynamicMaxY, 
                
                // Die unterschiedlichen Daten
                dataPoints: chartData,
                
                chartLabels: _buildChartLabels(),
              ),
            ),
            
            // Datum unten
            Text(
               _getDateLabel(), 
               style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // HELPER METHODEN (Logik für Daten und Kalender)
  // ----------------------------------------------------------------------

  void _showCalendarPicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate, // Startet beim aktuell gewählten Datum
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.mainColor,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  double _calculateMaxY(List<double> data) {
    if (data.isEmpty) return 100;
    
    // Höchsten Wert in der Liste finden
    double maxVal = data.reduce((curr, next) => curr > next ? curr : next);
    
    // Wenn alles 0 ist, geben wir standardmäßig 10 oder 100 zurück
    if (maxVal == 0) return 10;

    // Wir fügen 20% "Headroom" hinzu, damit die Kurve nicht am Rand klebt
    return maxVal * 1.2;
  }

  // --- HELPER: Unterschiedliche Daten generieren ---
 List<double> _generateDataPoints() {
    // Anzahl der Punkte im Monat muss korrekt sein (28, 29, 30 oder 31)
    int daysInMonth = _getDaysInMonth(_selectedDate);

    if (_selectedPeriod == "M") {
        // Generiere Mock-Daten exakt für die Anzahl der Tage im Monat
        return List.generate(daysInMonth, (index) {
           // Etwas Random-Varianz für den Graphen
           double baseValue = 200;
           if (widget.title == "Steps") baseValue = 8000;
           if (widget.title == "Activity") baseValue = 45;
           
           // Sinus-Welle + Zufall
           return baseValue + (index % 5) * (baseValue * 0.2) + (index % 3 == 0 ? baseValue * 0.3 : 0);
        });
    }

    // Für die anderen Zeiträume (D, W, Y) lassen wir die Logik wie vorher:
    switch (widget.title) {
      case "Steps":
        if (_selectedPeriod == "D") return [0, 0, 0, 50, 1200, 300, 4500, 800, 200, 1500, 200, 0];
        if (_selectedPeriod == "W") return [5000, 8000, 4500, 12000, 15000, 6000, 9000];
        if (_selectedPeriod == "Y") return [6000, 7000, 8000, 9000, 7500, 6000, 8000, 9500, 10000, 8500, 7000, 6500];
        return [];

      case "HR":
        if (_selectedPeriod == "Y") return List.generate(12, (i) => 60.0 + (i%3)*10);
        if (_selectedPeriod == "W") return [62, 65, 70, 110, 95, 80, 75];
        return [62, 65, 70, 110, 95, 80, 75, 68, 65, 62, 60, 58]; // D

      case "Activity":
        if (_selectedPeriod == "D") return [0, 10, 45, 10, 30, 0, 5, 20, 0, 0, 0, 0];
        if (_selectedPeriod == "W") return [30, 45, 60, 20, 90, 45, 50];
        if (_selectedPeriod == "Y") return List.generate(12, (i) => 30.0 + (i%4)*15);
        return [];

      case "Oxygen":
        return List.generate(_selectedPeriod == "Y" ? 12 : (_selectedPeriod == "W" ? 7 : 12), (i) => 97.0 + (i%3));

      case "Stress":
         if (_selectedPeriod == "Y") return List.generate(12, (i) => 20.0 + (i%5)*5);
         if (_selectedPeriod == "W") return [20, 30, 40, 25, 35, 20, 15];
         return [10, 20, 45, 30, 60, 40, 20, 15, 10, 25, 10, 5]; // D

      case "Sleep":
        if (_selectedPeriod == "Y") return List.generate(12, (i) => 6.5 + (i%3)*0.5);
        if (_selectedPeriod == "W") return [7.5, 6.0, 8.2, 7.8, 5.5, 9.0, 7.2];
        return [7.0, 7.5, 6.0, 8.0, 7.5, 6.5, 7.0]; // D (Mock)

      default:
        return [10, 20, 15, 40, 30, 20, 10];
    }
  }

  int _getDaysInMonth(DateTime date) {
    // Trick: Tag 0 des nächsten Monats ist der letzte Tag des aktuellen Monats
    return DateTime(date.year, date.month + 1, 0).day;
  }

  // Erstellt die Labels für die X-Achse
  Widget _buildChartLabels() {
    List<String> labels = [];

    switch (_selectedPeriod) {
      case "D": labels = ["06:00", "09:00", "12:00", "15:00", "18:00", "21:00"]; break;
      case "W": labels= ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]; break;
      case "M": int days = _getDaysInMonth(_selectedDate); labels = ["1", "5", "10", "15", "20", "25", "$days"]; break;
      case "Y": labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]; break;
    }

    return Row(
      mainAxisAlignment: labels.length > 4 
          ? MainAxisAlignment.spaceBetween 
          : MainAxisAlignment.spaceAround,
      children: labels.map((text) => Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      )).toList(),
    );
  }
  
  // Formatiert das Datum unten
  String _getDateLabel() {
    switch (_selectedPeriod) {
      case "D": 
        return DateFormat('MMMM d, y').format(_selectedDate);
      
      case "W":
        // Berechne Start (Montag) und Ende (Sonntag) der gewählten Woche
        final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return "${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}";
      
      case "M": 
        return DateFormat('MMMM y').format(_selectedDate);
      
      case "Y": 
        return DateFormat('y').format(_selectedDate);
      
      default: return "";
    }
  }

  // Mock-Werte für Demo
  String _getMockValue(String title) {
    switch (title) {
      case "Steps": return "8.500";
      case "HR": return "72";
      case "Sleep": return "7h 30m";
      default: return "42";
    }
  }
}