import 'package:flutter/material.dart';
import 'package:task_management/resources/local_storage.dart';

final primary = localStorage.getInt('primaryColor');

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor:
      localStorage.getInt('primaryColor') != null
          ? Color(primary!)
          : Colors.blue,
  scaffoldBackgroundColor: Colors.white,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black87),
  ),
  colorScheme: ColorScheme.light(
    primary:
        localStorage.getInt('primaryColor') != null
            ? Color(primary!)
            : Colors.blue,
    secondary: Colors.lightBlueAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    secondaryContainer: const Color.fromARGB(255, 210, 176, 255),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor:
      localStorage.getInt('primaryColor') != null
          ? Color(primary!)
          : Colors.blueGrey,
  scaffoldBackgroundColor: Colors.black,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
  ),
  colorScheme: ColorScheme.dark(
    primary:
        localStorage.getInt('primaryColor') != null
            ? Color(primary!)
            : Colors.blueGrey,
    secondary: Colors.teal,
    onPrimary: Colors.white,
    onSecondary: Colors.white70,
    secondaryContainer: const Color(0xFF19013A),
  ),
);
