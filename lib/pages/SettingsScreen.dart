import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_management/resources/ThemeNotifier.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum AppThemeMode { system, light, dark }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Theme Mode
  AppThemeMode _themeMode = AppThemeMode.system;

  // Wakelock
  bool _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load preferences from localStorage (Hive)
  Future<void> _loadPreferences() async {
    // Load theme mode
    String? modeStr = await localStorage.getString('themeMode');
    setState(() {
      switch (modeStr) {
        case 'light':
          _themeMode = AppThemeMode.light;
          break;
        case 'dark':
          _themeMode = AppThemeMode.dark;
          break;
        default:
          _themeMode = AppThemeMode.system;
      }
    });

    // Load wakelock status
    String? wakelockStr = await localStorage.getString('wakelock');
    bool wakelockStatus = (wakelockStr == 'true');
    wakelockStatus ? await WakelockPlus.enable() : await WakelockPlus.disable();
    setState(() {
      _wakelockEnabled = wakelockStatus;
    });

    int? primaryColorValue = await localStorage.getInt('primaryColor');
    int? secondaryColorValue = await localStorage.getInt('secondaryColor');

    int currentColor =
        Provider.of<ThemeNotifier>(context, listen: false).primaryColor.value;

    print("Current Color: $currentColor");
    print("Primary Color: $currentColor");

    if (primaryColorValue != null) {
      Provider.of<ThemeNotifier>(
        context,
        listen: false,
      ).setPrimaryColor(Color(primaryColorValue));
    }
    if (secondaryColorValue != null) {
      Provider.of<ThemeNotifier>(
        context,
        listen: false,
      ).setSecondaryColor(Color(secondaryColorValue));
    }
  }

  // Save theme mode
  Future<void> _saveThemeMode(AppThemeMode mode) async {
    String modeStr = mode.toString().split('.').last;
    await localStorage.putString('themeMode', modeStr);
    // Notify your app's theme provider here if needed
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    themeNotifier.setThemeMode(mode);
  }

  // Save wakelock

  Future<void> _toggleWakelock(bool value) async {
    if (value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
    await localStorage.putString('wakelock', value.toString());
    setState(() {
      _wakelockEnabled = value;
    });
  }

  final List<Color> colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Mode Section
          Text('Theme Mode', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),

          ToggleButtons(
            isSelected: [
              _themeMode == AppThemeMode.system,
              _themeMode == AppThemeMode.light,
              _themeMode == AppThemeMode.dark,
            ],
            onPressed: (index) {
              AppThemeMode selectedMode = AppThemeMode.values[index];
              setState(() {
                _themeMode = selectedMode;
              });
              _saveThemeMode(selectedMode);
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: Theme.of(context).colorScheme.primary,
            color: Theme.of(context).colorScheme.onSurface,
            constraints: const BoxConstraints(minHeight: 40, minWidth: 100),
            children: const [Text("System"), Text("Light"), Text("Dark")],
          ),

          const SizedBox(height: 24),
          const Divider(),

          Text('Color Scheme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              spacing: 8,
              children:
                  colorOptions.map((color) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          Provider.of<ThemeNotifier>(
                            context,
                            listen: false,
                          ).setPrimaryColor(color);
                          localStorage.putInt('primaryColor', color.value);
                        },
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 20,
                          child:
                              Provider.of<ThemeNotifier>(
                                        context,
                                      ).primaryColor.value ==
                                      color.value
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),

          // const SizedBox(height: 24),
          // Text(
          //   'Secondary Color',
          //   style: Theme.of(context).textTheme.titleMedium,
          // ),
          // const SizedBox(height: 8),
          // Wrap(
          //   spacing: 8,
          //   children:
          //       colorOptions.map((color) {
          //         return GestureDetector(
          //           onTap: () {
          //             Provider.of<ThemeNotifier>(
          //               context,
          //               listen: false,
          //             ).setSecondaryColor(color);
          //             localStorage.putInt('secondaryColor', color.value);
          //           },
          //           child: CircleAvatar(
          //             backgroundColor: color,
          //             radius: 20,
          //             child:
          //                 Provider.of<ThemeNotifier>(context).secondaryColor ==
          //                         color
          //                     ? const Icon(Icons.check, color: Colors.white)
          //                     : null,
          //           ),
          //         );
          //       }).toList(),
          // ),
          const Divider(),

          // Wakelock Toggle
          SwitchListTile(
            title: const Text('Keep Screen Awake'),
            value: _wakelockEnabled,
            onChanged: (value) => _toggleWakelock(value),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
