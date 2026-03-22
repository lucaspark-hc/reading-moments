import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/log/app_logger.dart';
import 'package:reading_moments_app/core/log/logged_state_mixin.dart';
import 'package:reading_moments_app/models/moment_model.dart';
import 'package:reading_moments_app/models/my_book_record_group_item.dart';
import 'package:reading_moments_app/screens/moments/moment_detail_screen.dart';
import 'package:reading_moments_app/services/moments_service.dart';
import 'package:reading_moments_app/services/my_records_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';

enum MyRecordFilterType { all, publicOnly, privateOnly }

class BookRecordsListScreen extends StatefulWidget {
  final MyBookRecordGroupItem group;

  const BookRecordsListScreen({
    super.key,
    required this.group,
  });

  @override
  State<BookRecordsListScreen> createState() => _BookRecordsListScreenState();
}

class _BookRecordsListScreenState extends State<BookRecordsListScreen>
    with LoggedStateMixin<BookRecordsListScreen> {
  final MomentsService _momentsService = MomentsService();
  final MyRecordsService _myRecordsService = MyRecordsService();

  bool _loading = true;
  bool _hasChanged = false;
  bool _openingRecordFlow = false;
  final Set<int> _processingMomentIds = <int>{};
  List<MomentModel> _allItems = [];
  MyRecordFilterType _filter = MyRecordFilterType.all;

  @override
  String get screenName => 'BookRecordsListScreen';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;

    setState(() => _loading = true);

    AppLogger.apiStart(
      'loadMomentsByBook',
      detail: 'bookId=${widget.group.bookId}, filter=$_filter',
    );

    try {
      final items = await _momentsService.loadMomentsByBook(widget.group.bookId);

      if (!mounted) return;

      setState(() {
        _allItems = items;
      });

      AppLogger.apiSuccess(
        'loadMomentsByBook',
        detail: 'count=${items.length}',
      );
    } catch (e, st) {
      AppLogger.apiError('loadMomentsByBook', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '기록 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<MomentModel> _filteredItems() {
    switch (_filter) {
      case MyRecordFilterType.publicOnly:
        return _allItems.where((e) => e.visibility == 'public').toList();
      case MyRecordFilterType.privateOnly:
        return _allItems.where((e) => e.visibility != 'public').toList();
      case MyRecordFilterType.all:
        return _allItems;
    }
  }

  void _close() {
    Navigator.pop(context, _hasChanged);
  }

  Future<void> _deleteRecord(MomentModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('기록 삭제'),
          content: const Text('이 기록을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    AppLogger.action(
      'DeleteMomentFromList',
      detail: 'momentId=${item.id}',
    );

    try {
      await _momentsService.deleteMoment(item.id);

      _hasChanged = true;

      if (!mounted) return;
      showToast(context, '기록이 삭제되었습니다.');
      await _loadItems();
    } catch (e, st) {
      AppLogger.apiError('deleteMoment(from list)', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '기록 삭제 실패: $e');
    }
  }

  Future<void> _toggleVisibility(MomentModel item) async {
    if (_processingMomentIds.contains(item.id)) return;

    final isPublic = item.visibility == 'public';
    final nextVisibility = isPublic ? 'private' : 'public';
    final confirmTitle = isPublic ? '비공개 전환' : '공개 전환';
    final confirmMessage = isPublic
        ? '이 기록을 비공개로 전환하시겠습니까?'
        : '이 기록을 공개로 전환하시겠습니까?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(confirmTitle),
          content: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    AppLogger.action(
      'ToggleMomentVisibilityFromList',
      detail:
          'momentId=${item.id}, from=${item.visibility}, to=$nextVisibility',
    );

    setState(() {
      _processingMomentIds.add(item.id);
    });

    try {
      await _myRecordsService.updateNote(
        noteId: item.id,
        quoteText: item.quoteText,
        explainText: item.explainText,
        noteText: item.noteText,
        visibility: nextVisibility,
        page: item.page,
      );

      _hasChanged = true;

      if (!mounted) return;
      showToast(
        context,
        isPublic ? '비공개로 전환되었습니다.' : '공개로 전환되었습니다.',
      );
      await _loadItems();
    } catch (e, st) {
      AppLogger.apiError('toggleMomentVisibility(from list)', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '공개 설정 변경 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingMomentIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _openEditDialog(MomentModel item) async {
    if (_openingRecordFlow) return;

    AppLogger.action(
      'OpenEditMomentDialogFromList',
      detail: 'momentId=${item.id}',
    );

    setState(() {
      _openingRecordFlow = true;
    });

    try {
      final updated = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditMomentDialog(
          item: item,
          myRecordsService: _myRecordsService,
        ),
      );

      if (updated == true) {
        _hasChanged = true;

        if (!mounted) return;

        await Future<void>.delayed(const Duration(milliseconds: 32));
        if (!mounted) return;

        await _loadItems();
        if (!mounted) return;

        showToast(context, '기록이 수정되었습니다.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingRecordFlow = false;
        });
      }
    }
  }

  Future<void> _openMomentDetail(MomentModel item) async {
    AppLogger.action(
      'OpenMomentDetailFromBookRecordsList',
      detail: 'momentId=${item.id}',
    );

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MomentDetailScreen(moment: item),
      ),
    );

    if (changed == true) {
      _hasChanged = true;
      await _loadItems();
    }
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<MyRecordFilterType>(
        segments: const [
          ButtonSegment<MyRecordFilterType>(
            value: MyRecordFilterType.all,
            label: Text('전체'),
            icon: Icon(Icons.list),
          ),
          ButtonSegment<MyRecordFilterType>(
            value: MyRecordFilterType.publicOnly,
            label: Text('공개'),
            icon: Icon(Icons.public),
          ),
          ButtonSegment<MyRecordFilterType>(
            value: MyRecordFilterType.privateOnly,
            label: Text('비공개'),
            icon: Icon(Icons.lock_outline),
          ),
        ],
        selected: {_filter},
        onSelectionChanged: (selected) {
          setState(() {
            _filter = selected.first;
          });
        },
      ),
    );
  }

  bool _isCompactQuoteCard(
    MomentModel item,
    bool hasExplain,
    bool hasThought,
  ) {
    final quoteLength = (item.quoteText ?? '').trim().length;
    return !hasExplain && !hasThought && quoteLength <= 40;
  }

  Widget _buildCompactQuoteCard(MomentModel item, bool isPublic) {
    return Row(
      children: [
        Chip(
          label: Text(isPublic ? '공개' : '비공개'),
        ),
        if (item.page != null) ...[
          const SizedBox(width: 8),
          Text(
            'p.${item.page}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '“${item.quoteText ?? ''}”',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullRecordCard(
    MomentModel item,
    bool isPublic,
    bool hasExplain,
    bool hasThought,
    bool isProcessing,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(label: Text(isPublic ? '공개' : '비공개')),
            if (item.page != null) ...[
              const SizedBox(width: 8),
              Text('p.${item.page}'),
            ],
            const Spacer(),
            if (isProcessing)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '문장',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '“${item.quoteText ?? ''}”',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        if (hasExplain) ...[
          const SizedBox(height: 12),
          const Text(
            '쉽게 풀어보기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              item.explainText!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
        if (hasThought) ...[
          const SizedBox(height: 12),
          const Text(
            '내 생각',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.noteText!.trim(),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          item.createdAt.toLocal().toString().substring(0, 16),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingMenu(MomentModel item, bool isProcessing) {
    if (isProcessing) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'open') {
          await _openMomentDetail(item);
        } else if (value == 'edit') {
          await _openEditDialog(item);
        } else if (value == 'toggle_visibility') {
          await _toggleVisibility(item);
        } else if (value == 'delete') {
          await _deleteRecord(item);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'open',
          child: Text('보기'),
        ),
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('수정'),
        ),
        PopupMenuItem<String>(
          value: 'toggle_visibility',
          child: Text(item.visibility == 'public' ? '비공개로 전환' : '공개로 전환'),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('삭제'),
        ),
      ],
    );
  }

  Widget _buildRecordCard(MomentModel item) {
    final isPublic = item.visibility == 'public';
    final hasExplain = (item.explainText ?? '').trim().isNotEmpty;
    final hasThought = (item.noteText ?? '').trim().isNotEmpty;
    final isProcessing = _processingMomentIds.contains(item.id);
    final isCompact = _isCompactQuoteCard(item, hasExplain, hasThought);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await _openMomentDetail(item);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: isCompact
                    ? _buildCompactQuoteCard(item, isPublic)
                    : _buildFullRecordCard(
                        item,
                        isPublic,
                        hasExplain,
                        hasThought,
                        isProcessing,
                      ),
              ),
              if (!isCompact) const SizedBox(width: 4),
              _buildTrailingMenu(item, isProcessing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final items = _filteredItems();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return const Center(child: Text('조건에 맞는 기록이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        children: [
          _buildFilterSection(),
          ...items.map(_buildRecordCard),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('책별 내 기록'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _close,
          ),
        ),
        body: _buildBody(),
      ),
    );
  }
}

class _EditMomentDialog extends StatefulWidget {
  final MomentModel item;
  final MyRecordsService myRecordsService;

  const _EditMomentDialog({
    required this.item,
    required this.myRecordsService,
  });

  @override
  State<_EditMomentDialog> createState() => _EditMomentDialogState();
}

class _EditMomentDialogState extends State<_EditMomentDialog> {
  late final TextEditingController _quoteController;
  late final TextEditingController _explainController;
  late final TextEditingController _noteController;
  late final TextEditingController _pageController;

  late String _visibility;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController(text: widget.item.quoteText ?? '');
    _explainController =
        TextEditingController(text: widget.item.explainText ?? '');
    _noteController = TextEditingController(text: widget.item.noteText ?? '');
    _pageController =
        TextEditingController(text: widget.item.page?.toString() ?? '');
    _visibility = widget.item.visibility == 'public' ? 'public' : 'private';
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _explainController.dispose();
    _noteController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final quoteText = _quoteController.text.trim();
    final explainText = _explainController.text.trim();
    final noteText = _noteController.text.trim();
    final pageText = _pageController.text.trim();
    final int? page = pageText.isEmpty ? null : int.tryParse(pageText);

    if (quoteText.isEmpty) {
      setState(() {
        _errorText = '문장을 입력하세요.';
      });
      return;
    }

    if (pageText.isNotEmpty && page == null) {
      setState(() {
        _errorText = '페이지는 숫자로 입력하세요.';
      });
      return;
    }

    AppLogger.action(
      'EditMomentFromList',
      detail: 'momentId=${widget.item.id}',
    );

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await widget.myRecordsService.updateNote(
        noteId: widget.item.id,
        quoteText: quoteText,
        explainText: explainText.isEmpty ? null : explainText,
        noteText: noteText.isEmpty ? null : noteText,
        visibility: _visibility,
        page: page,
      );

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 32));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.apiError(
        'editMomentFromList',
        e,
        stackTrace: st,
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
        _errorText = '수정 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('기록 수정'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_errorText ?? '').trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const Text(
              '문장',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quoteController,
              maxLines: 5,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '문장을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '쉽게 풀어보기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _explainController,
              maxLines: 4,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '쉽게 풀어보기 내용을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '내 생각',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '내 생각을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '페이지',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) async {
                if (!_saving) {
                  await _submit();
                }
              },
              decoration: const InputDecoration(
                hintText: '예: 100',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '공개 설정',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'public',
              groupValue: _visibility,
              title: const Text('공개'),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _visibility = value;
                      });
                    },
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'private',
              groupValue: _visibility,
              title: const Text('비공개'),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _visibility = value;
                      });
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop(false);
                },
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}