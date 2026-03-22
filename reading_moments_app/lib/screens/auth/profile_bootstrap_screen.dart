import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/screens/auth/login_screen.dart';
import 'package:reading_moments_app/screens/main_shell.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

class ProfileBootstrapScreen extends StatefulWidget {
  const ProfileBootstrapScreen({super.key});

  @override
  State<ProfileBootstrapScreen> createState() => _ProfileBootstrapScreenState();
}

class _ProfileBootstrapScreenState extends State<ProfileBootstrapScreen>
    with LoggedStateMixin<ProfileBootstrapScreen> {
  final _nickname = TextEditingController();
  bool _loading = true;
  String? _currentNick;

  @override
  String get screenName => 'ProfileBootstrapScreen';

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    setState(() => _loading = true);

    AppLogger.apiStart('loadMyProfile');

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        await supabase.auth.signOut();
        return;
      }

      final row = await supabase
          .from('users')
          .select('nickname')
          .eq('id', uid)
          .maybeSingle();

      final nick = row?['nickname'] as String?;
      _currentNick = nick;

      if (nick != null && nick.trim().isNotEmpty) {
        if (!mounted) return;
        AppLogger.info('Profile exists -> go MainShell(feed)');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }

      AppLogger.apiSuccess(
        'loadMyProfile',
        detail: 'hasNickname=${nick != null && nick.trim().isNotEmpty}',
      );
    } catch (e, st) {
      AppLogger.apiError('loadMyProfile', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '프로필 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNickname() async {
    final nick = _nickname.text.trim();
    if (nick.isEmpty) {
      showToast(context, '닉네임을 입력하세요.');
      return;
    }

    setState(() => _loading = true);

    AppLogger.action('SaveNickname', detail: 'nickname=$nick');

    try {
      final uid = supabase.auth.currentUser!.id;

      await supabase.from('users').upsert({
        'id': uid,
        'nickname': nick,
      });

      if (!mounted) return;
      showToast(context, '닉네임 저장 완료');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e, st) {
      AppLogger.apiError('saveNickname', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '닉네임 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '(unknown)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('닉네임 설정'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('로그인 계정: $email'),
                  const SizedBox(height: 14),
                  const Text('Reading Moments에서 사용할 닉네임을 입력해 주세요.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nickname,
                    decoration: InputDecoration(
                      labelText: '닉네임',
                      hintText: _currentNick ?? '예) 수훈',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _saveNickname,
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}