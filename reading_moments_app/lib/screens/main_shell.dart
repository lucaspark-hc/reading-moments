import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/screens/auth/login_screen.dart';
import 'package:reading_moments_app/screens/feed/feed_screen.dart';
import 'package:reading_moments_app/screens/library/my_library_screen.dart';
import 'package:reading_moments_app/screens/meetings/meetings_list_screen.dart';
import 'package:reading_moments_app/screens/records/my_records_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with LoggedStateMixin<MainShell> {
  int _index = 0;

  @override
  String get screenName => 'MainShell';

  late final List<Widget> _screens = [
    const FeedScreen(),
    const MeetingsListScreen(),
    const MyRecordsScreen(),
    const MyLibraryScreen(),
  ];

  String _title() {
    switch (_index) {
      case 0:
        return '공개피드';
      case 1:
        return '독서모임';
      case 2:
        return '내 기록';
      case 3:
        return '내 라이브러리';
      default:
        return 'ReadingMoments';
    }
  }

  void _go(int index) {
    AppLogger.action('ChangeMainTab', detail: 'from=$_index,to=$index');
    setState(() {
      _index = index;
    });
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: () async {
                  Navigator.pop(context);
                  await _signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          IconButton(
            onPressed: () => _go(0),
            icon: const Icon(Icons.public_outlined),
            tooltip: '공개피드',
          ),
          IconButton(
            onPressed: () => _go(1),
            icon: const Icon(Icons.groups_outlined),
            tooltip: '독서모임',
          ),
          IconButton(
            onPressed: () => _go(2),
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: '내 기록',
          ),
          IconButton(
            onPressed: () => _go(3),
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '내 라이브러리',
          ),
          IconButton(
            onPressed: _showAccountMenu,
            icon: const Icon(Icons.person_outline),
            tooltip: '계정',
          ),
        ],
      ),
      body: _screens[_index],
    );
  }
}