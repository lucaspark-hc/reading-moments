import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/services/moments_service.dart';

enum MomentVisibility { public, meeting, private }

class MomentCreateScreen extends StatefulWidget {
  final int bookId;
  final String? initialQuoteText;
  final String? initialEasyExplainText;
  final String initialInputMethod;

  const MomentCreateScreen({
    super.key,
    required this.bookId,
    this.initialQuoteText,
    this.initialEasyExplainText,
    this.initialInputMethod = 'manual',
  });

  @override
  State<MomentCreateScreen> createState() => _MomentCreateScreenState();
}

class _MomentCreateScreenState extends State<MomentCreateScreen>
    with LoggedStateMixin<MomentCreateScreen> {
  late final TextEditingController _quoteController;
  late final TextEditingController _noteController;
  late final TextEditingController _pageController;

  final MomentsService _momentsService = MomentsService();

  bool _saving = false;
  MomentVisibility _visibility = MomentVisibility.private;

  @override
  String get screenName => 'MomentCreateScreen';

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController(
      text: widget.initialQuoteText ?? '',
    );
    _noteController = TextEditingController();
    _pageController = TextEditingController();

    AppLogger.info(
      'MomentCreateScreen_Init | bookId=${widget.bookId}, inputMethod=${widget.initialInputMethod}, hasQuote=${(widget.initialQuoteText ?? '').trim().isNotEmpty}, hasEasyExplain=${(widget.initialEasyExplainText ?? '').trim().isNotEmpty}',
    );
    print(
      '📝 MomentCreateScreen_Init | bookId=${widget.bookId} | inputMethod=${widget.initialInputMethod} | hasQuote=${(widget.initialQuoteText ?? '').trim().isNotEmpty} | hasEasyExplain=${(widget.initialEasyExplainText ?? '').trim().isNotEmpty}',
    );
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

  int _estimateQuoteMinLines() {
    final text = _quoteController.text.trim();
    final isOcr = widget.initialInputMethod == 'ocr';

    if (text.isEmpty) {
      return isOcr ? 8 : 5;
    }

    final newlineCount = '\n'.allMatches(text).length;
    final length = text.length;

    if (isOcr) {
      if (newlineCount >= 5 || length > 260) return 12;
      if (newlineCount >= 3 || length > 180) return 10;
      if (newlineCount >= 2 || length > 120) return 8;
      return 7;
    }

    if (newlineCount >= 3 || length > 180) return 8;
    if (newlineCount >= 2 || length > 100) return 6;
    return 5;
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
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title),
        ],
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

  Widget _buildEasyExplainSection() {
    final explainText = widget.initialEasyExplainText?.trim() ?? '';
    if (explainText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '쉽게 풀어보기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            explainText,
            style: const TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _popWithRetry({
    bool result = true,
    int maxAttempts = 8,
  }) async {
    if (!mounted) return;

    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 16));

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return;

      try {
        final route = ModalRoute.of(context);
        final navigator = Navigator.of(context);

        if (route == null) {
          AppLogger.warn(
            'MomentCreateScreen_PopSkipped | reason=route_null, attempt=$attempt',
          );
          return;
        }

        if (!route.isCurrent) {
          AppLogger.warn(
            'MomentCreateScreen_PopSkipped | reason=route_not_current, attempt=$attempt',
          );
          return;
        }

        if (!navigator.canPop()) {
          AppLogger.warn(
            'MomentCreateScreen_PopSkipped | reason=cannot_pop, attempt=$attempt',
          );
          return;
        }

        navigator.pop(result);

        AppLogger.action(
          'MomentCreateScreen_PopSuccess',
          detail: 'attempt=$attempt',
        );
        print('↩️ MomentCreateScreen_PopSuccess | attempt=$attempt');
        return;
      } catch (e, st) {
        AppLogger.apiError(
          'MomentCreateScreen_PopRetry',
          e,
          stackTrace: st,
        );
        print('⚠️ MomentCreateScreen_PopRetry | attempt=$attempt | error=$e');

        if (attempt == maxAttempts) {
          _showSnack('저장은 완료되었지만 화면 이동이 지연되고 있습니다. 뒤로가기를 눌러주세요.');
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final quoteText = _quoteController.text.trim();
    final explainText = widget.initialEasyExplainText?.trim();
    final noteText = _noteController.text.trim();
    final pageText = _pageController.text.trim();
    final page = pageText.isEmpty ? null : int.tryParse(pageText);

    if (quoteText.isEmpty) {
      _showSnack('문장을 입력하세요');
      return;
    }

    if (pageText.isNotEmpty && page == null) {
      _showSnack('페이지는 숫자로 입력하세요');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnack('로그인이 필요합니다');
      return;
    }

    AppLogger.action(
      'SaveMoment',
      detail:
          'bookId=${widget.bookId}, inputMethod=${widget.initialInputMethod}, visibility=${_visibilityValue()}, hasExplain=${(explainText ?? '').isNotEmpty}, hasNote=${noteText.isNotEmpty}, page=${page ?? 'null'}',
    );
    print(
      '💾 SaveMoment | bookId=${widget.bookId} | inputMethod=${widget.initialInputMethod} | visibility=${_visibilityValue()} | hasExplain=${(explainText ?? '').isNotEmpty} | hasNote=${noteText.isNotEmpty} | page=${page ?? 'null'}',
    );

    setState(() {
      _saving = true;
    });

    try {
      await _momentsService.createMoment(
        userId: user.id,
        bookId: widget.bookId,
        quoteText: quoteText,
        explainText: (explainText == null || explainText.isEmpty)
            ? null
            : explainText,
        noteText: noteText.isEmpty ? null : noteText,
        page: page,
        visibility: _visibilityValue(),
        meetingId: null,
        type: 'quote',
        inputMethod: widget.initialInputMethod,
      );

      AppLogger.apiSuccess(
        'createMoment',
        detail: 'bookId=${widget.bookId}',
      );
      print('✅ createMoment SUCCESS | bookId=${widget.bookId}');

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      await _popWithRetry(result: true);
    } catch (e, st) {
      AppLogger.apiError('createMoment', e, stackTrace: st);
      print('❌ createMoment FAIL | $e');

      _showSnack('저장 실패: $e');

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
    final quoteMinLines = _estimateQuoteMinLines();

    return Scaffold(
      appBar: AppBar(
        title: Text(isOcr ? '스캔 문장 기록' : '문장 기록'),
      ),
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
              _buildEasyExplainSection(),
              if ((widget.initialEasyExplainText ?? '').trim().isNotEmpty)
                const SizedBox(height: 20),
              const Text(
                '좋은 문장',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quoteController,
                minLines: quoteMinLines,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '기록하고 싶은 문장이나 문단을 입력하세요.',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  helperText: isOcr ? '긴 문장은 아래로 늘려 보며 편집할 수 있습니다.' : null,
                ),
                onChanged: (_) {
                  if (!mounted) return;
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),
              const Text(
                '내 생각',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '떠오른 생각이 있으면 적어보세요. (선택)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
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