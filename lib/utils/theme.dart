
import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
          primaryColor: Colors.cyanAccent,
              scaffoldBackgroundColor: const Color(0xFF1c1c1e),
                  colorScheme: const ColorScheme.dark(
                        primary: Colors.cyanAccent,
                              secondary: Colors.pinkAccent,
                                    surface: Color(0xFF2a2a2e),
                                          onSurface: Colors.white,
                                              ),
                                                  textTheme: const TextTheme(
                                                        bodyLarge: TextStyle(color: Colors.white),
                                                              bodyMedium: TextStyle(color: Colors.white70),
                                                                  ),
                                                                      iconTheme: const IconThemeData(color: Colors.white70),
                                                                        );

                                                                          static final ThemeData lightTheme = ThemeData(
                                                                              brightness: Brightness.light,
                                                                                  primaryColor: Colors.blue,
                                                                                      scaffoldBackgroundColor: const Color(0xFFdcdcdc),
                                                                                          colorScheme: const ColorScheme.light(
                                                                                                primary: Colors.blue,
                                                                                                      secondary: Colors.deepOrange,
                                                                                                            surface: Colors.white,
                                                                                                                  onSurface: Colors.black,
                                                                                                                      ),
                                                                                                                          textTheme: const TextTheme(
                                                                                                                                bodyLarge: TextStyle(color: Colors.black),
                                                                                                                                      bodyMedium: TextStyle(color: Colors.black87),
                                                                                                                                          ),
                                                                                                                                              iconTheme: const IconThemeData(color: Colors.black54),
                                                                                                                                                );
                                                                                                                                                }
                                                                                                                                                