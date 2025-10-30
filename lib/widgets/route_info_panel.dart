import 'package:flutter/material.dart';

class RouteInfoPanel extends StatelessWidget {
  final IconData? maneuverIcon;
  final String? distanceToNextManeuver;
  final String? nextManeuverInstruction;
  final String? remainingDistance;
  final String? estimatedArrivalTime;

  const RouteInfoPanel({
    super.key,
    this.maneuverIcon,
    this.distanceToNextManeuver,
    this.nextManeuverInstruction,
    this.remainingDistance,
    this.estimatedArrivalTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final neonColor = isDarkMode ? Colors.cyanAccent : Colors.blue;

    if (nextManeuverInstruction == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 130,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.75) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: neonColor.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: neonColor.withOpacity(0.1),
              blurRadius: 12.0,
              spreadRadius: 2.0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (maneuverIcon != null)
                  Icon(maneuverIcon, color: neonColor, size: 32),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (distanceToNextManeuver != null)
                        Text(
                          distanceToNextManeuver!,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      if (nextManeuverInstruction != null)
                        Text(
                          nextManeuverInstruction!,
                          style: TextStyle(
                            fontSize: 17,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          softWrap: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: neonColor.withOpacity(0.3), height: 1),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (remainingDistance != null)
                  _buildInfoRow(neonColor, theme, remainingDistance!),
                if (remainingDistance != null && estimatedArrivalTime != null)
                  const SizedBox(height: 8),
                if (estimatedArrivalTime != null)
                  _buildInfoRow(neonColor, theme, estimatedArrivalTime!, isTime: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(Color neonColor, ThemeData theme, String text, {bool isTime = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isTime ? Icons.access_time_filled_outlined : Icons.route_outlined, color: neonColor, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}
