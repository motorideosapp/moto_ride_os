import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:moto_ride_os/l10n/app_localizations.dart';
import 'package:moto_ride_os/screens/welcome_screen.dart';
import 'package:moto_ride_os/utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MotoRideOS());
}

class MotoRideOS extends StatefulWidget {
  const MotoRideOS({super.key});

  @override
  State<MotoRideOS> createState() => _MotoRideOSState();

  static void setThemeMode(BuildContext context, ThemeMode newThemeMode) {
    final state = context.findAncestorStateOfType<_MotoRideOSState>();
    state?.setThemeMode(newThemeMode);
  }

  static void setLocale(BuildContext context, Locale newLocale) {
    _MotoRideOSState? state = context.findAncestorStateOfType<_MotoRideOSState>();
    state?.setLocale(newLocale);
  }
}

class _MotoRideOSState extends State<MotoRideOS> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.dark;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moto Ride OS',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [Locale('en', ''), Locale('tr', '')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      home: const WelcomeScreen(),
    );
  }
}
