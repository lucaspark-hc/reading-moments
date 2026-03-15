import 'package:flutter/material.dart';
import 'package:reading_moments_app/core/supabase_client.dart';
import 'package:reading_moments_app/models/book_model.dart';
import 'package:reading_moments_app/models/book_selection_item.dart';
import 'package:reading_moments_app/models/meeting_model.dart';
import 'package:reading_moments_app/models/wishlist_book_item.dart';
import 'package:reading_moments_app/screens/library/library_meeting_detail_screen.dart';
import 'package:reading_moments_app/screens/meetings/create_meeting_screen.dart';
import 'package:reading_moments_app/screens/selections/book_selection_detail_screen.dart';
import 'package:reading_moments_app/services/book_selections_service.dart';
import 'package:reading_moments_app/services/library_service.dart';
import 'package:reading_moments_app/services/meetings_service.dart';
import 'package:reading_moments_app/utils/app_utils.dart';
import 'package:reading_moments_app/widgets/current_user_banner.dart';

enum LibraryTabType { wishlist, selections, meetings }

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  final MeetingsService _meetingsService = MeetingsService();
  final LibraryService _libraryService = LibraryService();
  final BookSelectionsService _bookSelectionsService = BookSelectionsService();

  bool _loading = true;
  LibraryTabType _tab = LibraryTabType.wishlist;

  List<MeetingModel> _meetings = [];
  List<WishlistBookItem> _wishlistBooks = [];
  List<BookSelectionItem> _selections = [];

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    setState(() => _loading = true);

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (!mounted) return;
        showToast(context, '로그인이 필요합니다.');
        return;
      }

      final results = await Future.wait([
        _meetingsService.loadLibraryMeetings(uid),
        _libraryService.loadWishlistBooks(),
        _bookSelectionsService.loadMySelections(),
      ]);

      if (!mounted) return;

      setState(() {
        _meetings = results[0] as List<MeetingModel>;
        _wishlistBooks = results[1] as List<WishlistBookItem>;
        _selections = results[2] as List<BookSelectionItem>;
      });
    } catch (e) {
      if (!mounted) return;
      showToast(context, '내 라이브러리 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeWishlistBook(WishlistBookItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('읽고 싶은 책 제거'),
          content: Text('"${item.title}" 을(를) 읽고 싶은 책에서 제거하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('제거'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _libraryService.removeWishlistBook(item.bookId);

      if (!mounted) return;

      showToast(context, '읽고 싶은 책에서 제거되었습니다.');
      await _loadLibraryData();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '제거 실패: $e');
    }
  }

  Future<void> _openWishlistBook(WishlistBookItem item) async {
    final book = BookModel(
      id: item.bookId,
      isbn: item.isbn ?? '',
      title: item.title,
      author: item.author,
      coverUrl: item.coverUrl,
      category: null,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateMeetingScreen(initialBook: book)),
    );

    await _loadLibraryData();
  }

  String _meetingStatusLabel(String status) {
    switch (status) {
      case 'open':
        return '모집중';
      case 'in_progress':
        return '진행중';
      case 'closed':
        return '마감';
      case 'finished':
        return '종료';
      default:
        return status;
    }
  }

  Color _meetingBadgeColor(MeetingModel meeting) {
    final badge = meeting.badgeText ?? '';

    switch (badge) {
      case '신청중':
        return Colors.orange;
      case '참여중':
        return Colors.green;
      case '거절됨':
        return Colors.red;
      case '진행중':
        return Colors.teal;
      case '모집중':
        return Colors.blue;
      case '종료':
        return Colors.grey;
      default:
        switch (meeting.status) {
          case 'in_progress':
            return Colors.teal;
          case 'open':
            return Colors.blue;
          case 'closed':
            return Colors.orange;
          case 'finished':
            return Colors.grey;
          default:
            return Colors.blueGrey;
        }
    }
  }

  String _meetingBadgeText(MeetingModel meeting) {
    if (meeting.badgeText != null && meeting.badgeText!.trim().isNotEmpty) {
      return meeting.badgeText!;
    }
    return _meetingStatusLabel(meeting.status);
  }

  Widget _buildMeetingBadge(MeetingModel meeting) {
    final color = _meetingBadgeColor(meeting);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _meetingBadgeText(meeting),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTabSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<LibraryTabType>(
        segments: const [
          ButtonSegment<LibraryTabType>(
            value: LibraryTabType.wishlist,
            label: Text('읽고 싶은 책'),
            icon: Icon(Icons.bookmark_added_outlined),
          ),
          ButtonSegment<LibraryTabType>(
            value: LibraryTabType.selections,
            label: Text('책 선정'),
            icon: Icon(Icons.auto_stories_outlined),
          ),
          ButtonSegment<LibraryTabType>(
            value: LibraryTabType.meetings,
            label: Text('진행중인 모임'),
            icon: Icon(Icons.groups_outlined),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (selected) {
          setState(() {
            _tab = selected.first;
          });
        },
      ),
    );
  }

  Widget _buildWishlistView() {
    if (_wishlistBooks.isEmpty) {
      return const Center(child: Text('읽고 싶은 책이 없습니다. 피드나 모임에서 책을 추가해 보세요.'));
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView.builder(
        itemCount: _wishlistBooks.length,
        itemBuilder: (context, i) {
          final book = _wishlistBooks[i];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await _openWishlistBook(book);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((book.coverUrl ?? '').trim().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.coverUrl!,
                          width: 70,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 70,
                            height: 100,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Text(
                              '표지\n없음',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 70,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '표지\n없음',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('저자: ${book.author ?? "-"}'),
                          if ((book.isbn ?? '').trim().isNotEmpty)
                            Text('ISBN: ${book.isbn!}'),
                          const SizedBox(height: 8),
                          Text(
                            '추가일: ${formatDateTime(book.createdAt)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '탭하여 책 선정으로 이어가기',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'remove') {
                          await _removeWishlistBook(book);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: Text('제거'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionsView() {
    if (_selections.isEmpty) {
      return const Center(child: Text('저장한 책 선정 기록이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView.builder(
        itemCount: _selections.length,
        itemBuilder: (context, i) {
          final item = _selections[i];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(item.bookTitle),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((item.bookAuthor ?? '').trim().isNotEmpty)
                    Text('저자: ${item.bookAuthor!}'),
                  const SizedBox(height: 4),
                  Text(
                    item.selectionReason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '작성일: ${formatDateTime(item.createdAt)} · ${item.visibility == 'public' ? '공개' : '비공개'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookSelectionDetailScreen(selection: item),
                  ),
                );
                await _loadLibraryData();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeetingsView() {
    if (_meetings.isEmpty) {
      return const Center(child: Text('진행중인 모임이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView.builder(
        itemCount: _meetings.length,
        itemBuilder: (context, i) {
          final m = _meetings[i];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LibraryMeetingDetailScreen(meeting: m),
                  ),
                );
                await _loadLibraryData();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            m.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMeetingBadge(m),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (m.book != null)
                      Text('책: ${m.book!.title} / ${m.book!.author ?? "-"}'),
                    Text('일시: ${formatDateTime(m.meetingDate)}'),
                    Text('장소: ${m.location ?? "-"}'),
                    const SizedBox(height: 6),
                    Text(
                      m.isHost ? '역할: 호스트' : '역할: 참여자',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_tab) {
      case LibraryTabType.wishlist:
        return _buildWishlistView();
      case LibraryTabType.selections:
        return _buildSelectionsView();
      case LibraryTabType.meetings:
        return _buildMeetingsView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 라이브러리')),
      body: Column(
        children: [
          const CurrentUserBanner(),
          _buildTabSection(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
