import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// A collapsible accordion widget used to cleanly group related settings options.
class SettingsSection extends StatelessWidget {
  /// The persistent header title visible even when collapsed.
  final String title;

  /// The list of configuration widgets revealed when expanded.
  final List<Widget> children;

  /// Creates a new [SettingsSection] instance.
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(title, style: AppTextStyles.subsubtitle),
        iconColor: AppColors.mainColor,
        collapsedIconColor: AppColors.textSecondary,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
