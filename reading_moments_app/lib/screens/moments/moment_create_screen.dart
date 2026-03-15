import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/services/moments_service.dart';

enum MomentVisibility { public, meeting, private }

class MomentCreateScreen extends StatefulWidget {
  final int bookId;
  final String? initialQuoteText;
  final String initialInputMethod;

  const MomentCreateScreen({
    super.key,
    required this.bookId,
    this.initialQuoteText,
    this.initialInputMethod = 'manual',
  });

  @override
  State<MomentCreateScreen> createState() => _MomentCreateScreenState();
}

class _MomentCreateScreenState extends State<MomentCreateScreen> {
  late final TextEditingController _quoteController;
  late final TextEditingController _noteController;
  late final TextEditingController _pageController;

  final MomentsService _momentsService = MomentsService();

  bool _saving = false;
  MomentVisibility _visibility = MomentVisibility.private;

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController(
      text: widget.initialQuoteText ?? '',
    );
    _noteController = TextEditingController();
    _pageController = TextEditingController();
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _noteController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _visibilityValue() {
    switch (_visibility) {
      case MomentVisibility.public:
        return 'public';
      case MomentVisibility.meeting:
        return 'meeting';
      case MomentVisibility.private:
        return 'private';
    }
  }

  Widget _buildVisibilityOption({
    required MomentVisibility value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<MomentVisibility>(
      contentPadding: EdgeInsets.zero,
      value: value,
      groupValue: _visibility,
      onChanged: (selected) {
        if (selected == null) return;
        setState(() {
          _visibility = selected;
        });
      },
      title: Row(
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title)],
      ),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildVisibilitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '공개 대상',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildVisibilityOption(
          value: MomentVisibility.public,
          icon: Icons.public,
          title: '전체 공개',
          subtitle: '전체 피드에서 다른 사람도 볼 수 있습니다.',
        ),
        _buildVisibilityOption(
          value: MomentVisibility.meeting,
          icon: Icons.groups,
          title: '모임 공유',
          subtitle: '나중에 모임 연결 기능과 함께 사용할 수 있습니다.',
        ),
        _buildVisibilityOption(
          value: MomentVisibility.private,
          icon: Icons.lock_outline,
          title: '나만 보기',
          subtitle: '내 라이브러리에서만 볼 수 있습니다.',
        ),
      ],
    );
  }

  Future<void> _save() async {
    final quoteText = _quoteController.text.trim();
    final noteText = _noteController.text.trim();
    final page = int.tryParse(_pageController.text.trim());

    if (quoteText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문장을 입력하세요')));
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _momentsService.createMoment(
        userId: user.id,
        bookId: widget.bookId,
        quoteText: quoteText,
        noteText: noteText.isEmpty ? null : noteText,
        page: page,
        visibility: _visibilityValue(),
        meetingId: null,
        type: 'quote',
        inputMethod: widget.initialInputMethod,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문장이 저장되었습니다')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOcr = widget.initialInputMethod == 'ocr';

    return Scaffold(
      appBar: AppBar(title: Text(isOcr ? '스캔 문장 기록' : '문장 기록')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOcr) ...[
                const Text(
                  '스캔한 문장이 자동으로 입력되었습니다. 필요한 경우 편집 후 저장하세요.',
                  style: TextStyle(color: Colors.blueGrey, height: 1.5),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                '좋은 문장',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quoteController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '기록하고 싶은 문장이나 문단을 입력하세요.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '내 생각',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '떠오른 생각이 있으면 적어보세요. (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '페이지',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '예: 128 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _buildVisibilitySelector(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
