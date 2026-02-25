import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// Represents a distinct category or block of educational content within an info sheet.
class InfoSectionData {
  final String title;
  final List<InfoItemData> items;

  InfoSectionData({required this.title, required this.items});
}

/// Represents a single educational concept, optionally accompanied by a colored legend dot or icon.
class InfoItemData {
  final String title;
  final String description;
  final Color? color;
  final IconData? icon;

  InfoItemData({
    required this.title,
    required this.description,
    this.color,
    this.icon,
  });
}

/// Helper function to summon a standardized, scrollable bottom sheet containing educational context about a specific metric.
void showMetricInfoSheet(
  BuildContext context, {
  required String sheetTitle,
  required List<InfoSectionData> sections,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sheetTitle,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 20),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  children: sections.map((section) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...section.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _InfoItemWidget(item: item),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Internal widget responsible for laying out the title, description, and visual cue of a single concept.
class _InfoItemWidget extends StatelessWidget {
  final InfoItemData item;

  const _InfoItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2, right: 12),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: item.color ?? Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: item.icon != null
              ? Icon(item.icon, size: 12, color: Colors.white70)
              : null,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTextStyles.bodywhite),
              const SizedBox(height: 4),
              Text(item.description, style: AppTextStyles.bodygrey),
            ],
          ),
        ),
      ],
    );
  }
}
