
import 'package:flutter/material.dart';

class ManeuverPanel extends StatelessWidget {
  final IconData? maneuverIcon;
  final String? distanceToNextManeuver;
  final String? nextManeuverInstruction;
  final String? remainingDistance;
  final String? estimatedArrivalTime;

  const ManeuverPanel({
    super.key,
    required this.maneuverIcon,
    required this.distanceToNextManeuver,
    required this.nextManeuverInstruction,
    required this.remainingDistance,
    required this.estimatedArrivalTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    // Don't build anything if there's no instruction to show
    if (nextManeuverInstruction == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 10, top: 90), // Margin to position it below the search bar
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDarkMode ? Colors.cyanAccent.withOpacity(0.2) : Colors.blue.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.cyanAccent.withOpacity(0.05) : Colors.blue.withOpacity(0.1),
            blurRadius: 8.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      width: 180, // Fixed width as requested
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Maneuver Icon and distance to it
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (maneuverIcon != null)
                Icon(maneuverIcon, color: textColor, size: 60),
              const SizedBox(width: 10),
              if (distanceToNextManeuver != null)
                Expanded(
                  child: Text(
                    distanceToNextManeuver!,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    softWrap: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Next instruction text
          if (nextManeuverInstruction != null)
            Text(
              nextManeuverInstruction!,
              style: TextStyle(
                color: textColor.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

          const Divider(height: 20, thickness: 0.5),

          // Total Remaining Distance
          Row(
            children: [
              Icon(Icons.signpost_outlined, color: textColor.withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              if (remainingDistance != null)
                Text(
                  '$remainingDistance km',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Estimated Arrival Time
          Row(
            children: [
              Icon(Icons.watch_later_outlined, color: textColor.withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              if (estimatedArrivalTime != null)
                Text(
                  estimatedArrivalTime!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
