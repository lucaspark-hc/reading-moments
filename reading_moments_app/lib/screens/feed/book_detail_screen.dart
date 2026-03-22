import 'package:flutter/material.dart';

import '../../core/log/app_logger.dart';
import '../../core/log/logged_state_mixin.dart';
import '../../core/supabase_client.dart';
import '../../models/book_model.dart';
import '../../utils/app_utils.dart';

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  final BookModel? initialBook;

  const BookDetailScreen({
    super.key,
    int? bookId,
    BookModel? book,
  })  : assert(bookId != null || book != null),
        bookId = bookId ?? book!.id,
        initialBook = book;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen>
    with LoggedStateMixin<BookDetailScreen> {
  bool _loading = true;
  BookModel? _book;
  List<_PublicSelectionView> _selectionItems = [];
  List<_PublicMomentView> _momentItems = [];

  @override
  String get screenName => 'BookDetailScreen';

  @override
  void initState() {
    super.initState();
    _book = widget.initialBook;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    AppLogger.apiStart(
      'loadBookExploreDetail',
      detail: 'bookId=${widget.bookId}',
    );

    try {
      await Future.wait([
        _loadBook(),
        _loadPublicSelections(),
        _loadPublicMoments(),
      ]);

      AppLogger.apiSuccess(
        'loadBookExploreDetail',
        detail:
            'bookId=${widget.bookId}, selectionCount=${_selectionItems.length}, momentCount=${_momentItems.length}',
      );
    } catch (e, st) {
      AppLogger.apiError('loadBookExploreDetail', e, stackTrace: st);
      if (!mounted) return;
      showToast(context, '책 소개 화면 조회 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadBook() async {
    if (_book != null) return;

    final response = await supabase
        .from('books')
        .select('id, isbn, title, author, cover_url, category, description')
        .eq('id', widget.bookId)
        .maybeSingle();

    if (response == null) {
      throw Exception('책 정보를 찾을 수 없습니다.');
    }

    _book = BookModel.fromJson(response);
  }

  Future<void> _loadPublicSelections() async {
    final response = await supabase
        .from('book_selections')
        .select('''
          id,
          selection_reason,
          book_description,
          created_at,
          users:user_id (
            nickname
          )
        ''')
        .eq('book_id', widget.bookId)
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .limit(10);

    final rows = (response as List).cast<Map<String, dynamic>>();

    _selectionItems = rows.map((row) {
      final userMap = row['users'] as Map<String, dynamic>?;
      return _PublicSelectionView(
        nickname: (userMap?['nickname'] ?? '알 수 없음') as String,
        selectionReason: (row['selection_reason'] ?? '') as String,
        bookDescription: row['book_description'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  Future<void> _loadPublicMoments() async {
    final response = await supabase
        .from('reading_moments')
        .select('''
          id,
          user_id,
          quote_text,
          note_text,
          page,
          created_at
        ''')
        .eq('book_id', widget.bookId)
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .limit(10);

    final rows = (response as List).cast<Map<String, dynamic>>();

    if (rows.isEmpty) {
      _momentItems = [];
      return;
    }

    final userIds = rows.map((e) => e['user_id'] as String).toSet().toList();

    final userResponse = await supabase
        .from('users')
        .select('id, nickname')
        .inFilter('id', userIds);

    final userRows = (userResponse as List).cast<Map<String, dynamic>>();
    final Map<String, String> nicknameByUserId = {
      for (final row in userRows)
        row['id'] as String: (row['nickname'] ?? '알 수 없음') as String,
    };

    _momentItems = rows.map((row) {
      final userId = row['user_id'] as String;
      return _PublicMomentView(
        nickname: nicknameByUserId[userId] ?? '알 수 없음',
        quoteText: row['quote_text'] as String?,
        noteText: row['note_text'] as String?,
        page: row['page'] as int?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  Widget _buildBookHeader() {
    final book = _book;
    if (book == null) {
      return const SizedBox.shrink();
    }

    final hasAuthor = (book.author ?? '').trim().isNotEmpty;
    final hasDescription = (book.description ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((book.coverUrl ?? '').trim().isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    book.coverUrl!,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Text('표지 이미지 없음'),
                    ),
                  ),
                ),
              ),
            if ((book.coverUrl ?? '').trim().isNotEmpty) const SizedBox(height: 18),
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.35,
              ),
            ),
            if (hasAuthor) ...[
              const SizedBox(height: 8),
              Text(
                book.author!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              '책 소개',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasDescription
                  ? book.description!.trim()
                  : '아직 등록된 책 소개가 없습니다.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(_PublicSelectionView item) {
    final hasDescription = (item.bookDescription ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.nickname} · ${formatDateTime(item.createdAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.selectionReason,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
            if (hasDescription) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.bookDescription!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMomentCard(_PublicMomentView item) {
    final hasQuote = (item.quoteText ?? '').trim().isNotEmpty;
    final hasThought = (item.noteText ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.nickname} · ${formatDateTime(item.createdAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (item.page != null) ...[
              const SizedBox(height: 6),
              Text(
                'p.${item.page}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            if (hasQuote) ...[
              const SizedBox(height: 12),
              Text(
                '“${item.quoteText!}”',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
            if (hasThought) ...[
              const SizedBox(height: 10),
              Text(
                item.noteText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        children: [
          _buildBookHeader(),
          _buildSectionTitle(
            '이 책을 읽는 이유',
            '사람들이 왜 이 책을 고르고 있는지 살펴보세요.',
          ),
          if (_selectionItems.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('아직 공개된 책 선정 이유가 없습니다.'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _selectionItems.map(_buildSelectionCard).toList(),
              ),
            ),
          _buildSectionTitle(
            '이 책의 생각들',
            '이 책에서 남겨진 공개 문장과 생각의 일부입니다.',
          ),
          if (_momentItems.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('아직 공개된 기록이 없습니다.'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _momentItems.map(_buildMomentCard).toList(),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_book?.title ?? '').trim().isEmpty ? '책 소개' : _book!.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _buildBody(),
    );
  }
}

class _PublicSelectionView {
  final String nickname;
  final String selectionReason;
  final String? bookDescription;
  final DateTime createdAt;

  const _PublicSelectionView({
    required this.nickname,
    required this.selectionReason,
    required this.bookDescription,
    required this.createdAt,
  });
}

class _PublicMomentView {
  final String nickname;
  final String? quoteText;
  final String? noteText;
  final int? page;
  final DateTime createdAt;

  const _PublicMomentView({
    required this.nickname,
    required this.quoteText,
    required this.noteText,
    required this.page,
    required this.createdAt,
  });
}