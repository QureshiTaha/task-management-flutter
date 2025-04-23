import 'package:flutter/material.dart';
import 'package:task_management/resources/local_storage.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    var isAdmin =
        user['userRole'] != null && user['userRole'] >= 2 ? true : false;
    return new SizedBox(
      width: MediaQuery.of(context).size.width * 0.85, //20.0,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: ThemeData().colorScheme.primary),
              accountName: Text(
                "${user['userFirstName'] ?? 'User'} ${user['userSurname'] ?? ''}",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user['userEmail'] ?? 'user@example.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: ThemeData().colorScheme.onSurface,
                radius: 39.0,
                child: CircleAvatar(
                  backgroundColor: ThemeData().colorScheme.secondary,
                  radius: 35.0,
                  child: Text(
                    user['userFirstName'] != null
                        ? user['userFirstName'][0] + user['userSurname'][0]
                        : 'U',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: ThemeData().colorScheme.onSecondary,
                      shadows: [
                        Shadow(
                          color: ThemeData().colorScheme.onSurface,
                          offset: Offset(0.5, 0.5),
                          blurRadius: 10.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_rounded),
              title: Text('Home'),
              onTap: () => Navigator.popAndPushNamed(context, '/home'),
            ),
            ListTile(
              leading: Icon(Icons.task_rounded),
              title: Text('My Tasks'),
              onTap: () => Navigator.pushNamed(context, '/my-tasks'),
            ),
            ListTile(
              leading: Icon(Icons.add_to_drive_rounded),
              title: Text('My Drive'),
              onTap: () => Navigator.pushNamed(context, '/drive'),
            ),
            isAdmin
                ? Divider(
                  color: Colors.black,
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 16,
                )
                : Spacer(),
            isAdmin
                ? ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('Users'),
                  onTap: () => Navigator.pushNamed(context, '/users'),
                )
                : Spacer(),
            isAdmin
                ? ListTile(
                  leading: Icon(Icons.align_horizontal_left),
                  title: Text('Projects'),
                  onTap: () => Navigator.pushNamed(context, '/projects'),
                )
                : Spacer(),

            Divider(
              color: Colors.black,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            ListTile(
              leading: Icon(Icons.message_rounded),
              title: Text('Messenger'),
              onTap: () => Navigator.pushNamed(context, '/message-home'),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                localStorage.setLoggedIn(false);
                localStorage.remove("fcmToken");
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
