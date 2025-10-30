import 'package:flutter/material.dart';
import 'package:moto_ride_os/main.dart';

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        // Mevcut temaya göre doğru ikonu göster
        Theme.of(context).brightness == Brightness.dark
            ? Icons.light_mode_rounded
            : Icons.dark_mode_rounded,
        color: Theme.of(context).iconTheme.color,
      ),
      onPressed: () {
        // Butona tıklandığında temayı değiştir
        final newThemeMode = Theme.of(context).brightness == Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark;
        MotoRideOS.setThemeMode(context, newThemeMode);
      },
    );
  }
}
