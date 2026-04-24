import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'logs_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    ChatScreen(),
    HistoryScreen(),
    SettingsScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AiAnywhereTheme.divider, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chat_bubble),
              activeIcon: Icon(CupertinoIcons.chat_bubble_fill),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.clock),
              activeIcon: Icon(CupertinoIcons.clock_fill),
              label: 'History',
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.settings),
              activeIcon: Icon(CupertinoIcons.settings_solid),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: _LogsIcon(active: false),
              activeIcon: _LogsIcon(active: true),
              label: 'Logs',
            ),
          ],
        ),
      ),
    );
  }
}

class _LogsIcon extends StatelessWidget {
  final bool active;
  const _LogsIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return Icon(
      active
          ? CupertinoIcons.doc_text_fill
          : CupertinoIcons.doc_text,
    );
  }
}
