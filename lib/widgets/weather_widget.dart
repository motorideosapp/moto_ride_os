import 'package:flutter/material.dart';

class WeatherWidget extends StatelessWidget {
  final String temperature;
  final String condition;
  final IconData weatherIcon;
  final bool isLoading;
  final bool isCompact; // Yeni özellik

  const WeatherWidget({
    super.key,
    this.temperature = '--',
    this.condition = 'Yükleniyor...',
    this.weatherIcon = Icons.cloud_off,
    this.isLoading = true,
    this.isCompact = false, // Varsayılan olarak normal boyutta
  });

  @override
  Widget build(BuildContext context) {
    // Kompakt moda göre boyutları ayarla
    final double iconSize = isCompact ? 28 : 38;
    final double tempFontSize = isCompact ? 24 : 30;
    final double condFontSize = isCompact ? 12 : 14;
    final double horizontalPadding = isCompact ? 12 : 20;
    final double verticalPadding = isCompact ? 4 : 8;
    final double spacing = isCompact ? 8 : 12;

    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // Öğeleri dikeyde ortala
        children: [
          Icon(
            weatherIcon,
            size: iconSize,
            color: Theme.of(context).iconTheme.color, // Tema rengini kullan
            shadows: [
              Shadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 10.0,
              ),
            ],
          ),
          SizedBox(width: spacing),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$temperature°C',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Theme.of(context).textTheme.bodyLarge?.color, // Tema rengini kullan
                  fontSize: tempFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text(
                condition,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color, // Tema rengini kullan
                  fontSize: condFontSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
