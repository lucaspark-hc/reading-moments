import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../models/test_account.dart';
import '../../utils/app_utils.dart';
import 'profile_bootstrap_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false;

  String _normalizeEmail(String v) => v.trim().toLowerCase();

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signUp(
        email: _normalizeEmail(_email.text),
        password: _pw.text.trim(),
      );
      if (!mounted) return;
      showToast(context, '회원가입 완료');
    } on AuthException catch (e) {
      if (!mounted) return;
      showToast(context, '회원가입 실패: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '회원가입 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _normalizeEmail(_email.text),
        password: _pw.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfileBootstrapScreen()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showToast(context, '로그인 실패: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickLogin(TestAccount acc) async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signOut();
      await supabase.auth.signInWithPassword(
        email: _normalizeEmail(acc.email),
        password: acc.password.trim(),
      );
      if (!mounted) return;
      showToast(context, '${acc.label} 로그인 완료');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfileBootstrapScreen()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showToast(context, '빠른 로그인 실패: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '빠른 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReadingMoments 로그인'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('로그인'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _loading ? null : _signUp,
                child: const Text('회원가입'),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '테스트 계정 원클릭 로그인 (전환 시 자동 로그아웃)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kTestAccounts.map((acc) {
                return SizedBox(
                  width: 130,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _quickLogin(acc),
                    child: Text(acc.label),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}