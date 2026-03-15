import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class CurrentUserBanner extends StatefulWidget {
  const CurrentUserBanner({super.key});

  @override
  State<CurrentUserBanner> createState() => _CurrentUserBannerState();
}

class _CurrentUserBannerState extends State<CurrentUserBanner> {
  bool _loading = true;
  String? _nickname;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _nickname = null;
          _email = null;
        });
        return;
      }

      final profile = await supabase
          .from('users')
          .select('nickname')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _nickname = profile?['nickname'] as String?;
        _email = user.email;
      });
    } catch (_) {
      if (!mounted) return;
      final user = supabase.auth.currentUser;
      setState(() {
        _nickname = null;
        _email = user?.email;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.grey.shade100,
        child: const Text('현재 사용자 확인 중...'),
      );
    }

    final nicknameText =
        (_nickname ?? '').trim().isEmpty ? '닉네임 없음' : _nickname!;
    final emailText = (_email ?? '').trim().isEmpty ? '이메일 없음' : _email!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.amber.shade100),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '현재 사용자: $nicknameText ($emailText)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}