import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// A specialized list tile allowing the user to manually type a custom name
/// for a generic "Individual" workout activity.
class IndividualActivityTile extends StatefulWidget {
  /// The icon representing this custom activity.
  final IconData icon;

  /// Callback executed when the user submits their custom text.
  final Function(String) onArrowPressed;

  /// Creates a new [IndividualActivityTile] instance.
  const IndividualActivityTile({
    super.key,
    required this.icon,
    required this.onArrowPressed,
  });

  @override
  State<IndividualActivityTile> createState() => _IndividualActivityTileState();
}

class _IndividualActivityTileState extends State<IndividualActivityTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an activity name"),
          duration: Duration(seconds: 1),
          backgroundColor: AppColors.mainColor,
        ),
      );
      return;
    }
    widget.onArrowPressed(text);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      leading: Icon(widget.icon, color: AppColors.mainColor),

      title: Transform.translate(
        offset: const Offset(0, 0),
        child: TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppColors.mainColor,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: "ADD NEW ACTIVITY",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),

      trailing: IconButton(
        onPressed: _submit,
        icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
