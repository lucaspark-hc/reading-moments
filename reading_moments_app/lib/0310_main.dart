import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const List<TestAccount> kTestAccounts = [
  TestAccount(label: '독서왕1', email: 'reading1@test.com', password: '123456'),
  TestAccount(label: '독서왕2', email: 'reading2@test.com', password: '123456'),
  TestAccount(label: '독서왕3', email: 'reading3@test.com', password: '123456'),
  TestAccount(label: '독서왕4', email: 'reading4@test.com', password: '123456'),
  TestAccount(label: '독서왕5', email: 'reading5@test.com', password: '123456'),
];

class TestAccount {
  final String label;
  final String email;
  final String password;

  const TestAccount({
    required this.label,
    required this.email,
    required this.password,
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnon = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnon == null ||
      supabaseAnon.isEmpty) {
    throw Exception('❌ .env에 SUPABASE_URL / SUPABASE_ANON_KEY가 없습니다.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnon,
  );

  runApp(const ReadingMomentsApp());
}

final supabase = Supabase.instance.client;
String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:3000';

class ReadingMomentsApp extends StatelessWidget {
  const ReadingMomentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReadingMoments',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const AuthGate(),
    );
  }
}

/// ======================================================
/// Models
/// ======================================================

class BookModel {
  final int id;
  final String isbn;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? category;

  BookModel({
    required this.id,
    required this.isbn,
    required this.title,
    this.author,
    this.coverUrl,
    this.category,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as int,
      isbn: (json['isbn'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String?,
      category: json['category'] as String?,
    );
  }
}

class BookSearchResult {
  final String googleBookId;
  final String title;
  final String author;
  final String isbn;
  final String coverUrl;
  final String description;
  final String publisher;
  final String publishedDate;

  BookSearchResult({
    required this.googleBookId,
    required this.title,
    required this.author,
    required this.isbn,
    required this.coverUrl,
    required this.description,
    required this.publisher,
    required this.publishedDate,
  });

  factory BookSearchResult.fromJson(Map<String, dynamic> json) {
    return BookSearchResult(
      googleBookId: (json['googleBookId'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      author: (json['author'] ?? '') as String,
      isbn: (json['isbn'] ?? '') as String,
      coverUrl: (json['coverUrl'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      publisher: (json['publisher'] ?? '') as String,
      publishedDate: (json['publishedDate'] ?? '') as String,
    );
  }
}

class MeetingModel {
  final int id;
  final String? hostId;
  final int? bookId;
  final String title;
  final DateTime meetingDate;
  final String? location;
  final int maxParticipants;
  final String status;
  final DateTime? createdAt;
  final BookModel? book;
  final String? hostReason;

  MeetingModel({
    required this.id,
    required this.hostId,
    required this.bookId,
    required this.title,
    required this.meetingDate,
    required this.location,
    required this.maxParticipants,
    required this.status,
    required this.createdAt,
    required this.book,
    required this.hostReason,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    final bookJson = json['books'];
    return MeetingModel(
      id: json['id'] as int,
      hostId: json['host_id'] as String?,
      bookId: json['book_id'] as int?,
      title: (json['title'] ?? '') as String,
      meetingDate: DateTime.parse(json['meeting_date'] as String),
      location: json['location'] as String?,
      maxParticipants: (json['max_participants'] ?? 5) as int,
      status: (json['status'] ?? 'open') as String,
      createdAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      book: bookJson is Map<String, dynamic> ? BookModel.fromJson(bookJson) : null,
      hostReason: json['host_reason'] as String?,
    );
  }
}

class QuestionItem {
  final int id;
  final int? meetingId;
  final String? createdBy;
  final String question;
  final DateTime? createdAt;

  QuestionItem({
    required this.id,
    required this.meetingId,
    required this.createdBy,
    required this.question,
    required this.createdAt,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      id: json['id'] as int,
      meetingId: json['meeting_id'] as int?,
      createdBy: json['created_by'] as String?,
      question: (json['question'] ?? '') as String,
      createdAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

class ParticipantItem {
  final int id;
  final int meetingId;
  final String userId;
  final String status;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final String? nickname;

  ParticipantItem({
    required this.id,
    required this.meetingId,
    required this.userId,
    required this.status,
    required this.requestedAt,
    required this.approvedAt,
    required this.nickname,
  });

  factory ParticipantItem.fromJson(Map<String, dynamic> json) {
    final usersJson = json['users'];
    return ParticipantItem(
      id: json['id'] as int,
      meetingId: json['meeting_id'] as int,
      userId: json['user_id'] as String,
      status: (json['status'] ?? '') as String,
      requestedAt:
          json['requested_at'] != null ? DateTime.tryParse(json['requested_at']) : null,
      approvedAt:
          json['approved_at'] != null ? DateTime.tryParse(json['approved_at']) : null,
      nickname: usersJson is Map<String, dynamic>
          ? usersJson['nickname'] as String?
          : null,
    );
  }
}

class AnswerItem {
  final int id;
  final int questionId;
  final int? meetingId;
  final String userId;
  final String answer;
  final DateTime? createdAt;
  final String? nickname;
  final String? questionText;

  AnswerItem({
    required this.id,
    required this.questionId,
    required this.meetingId,
    required this.userId,
    required this.answer,
    required this.createdAt,
    required this.nickname,
    required this.questionText,
  });

  factory AnswerItem.fromJson(Map<String, dynamic> json) {
    final usersJson = json['users'];
    final questionsJson = json['questions'];
    return AnswerItem(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      meetingId: json['meeting_id'] as int?,
      userId: json['user_id'] as String,
      answer: (json['answer'] ?? '') as String,
      createdAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      nickname: usersJson is Map<String, dynamic>
          ? usersJson['nickname'] as String?
          : null,
      questionText: questionsJson is Map<String, dynamic>
          ? questionsJson['question'] as String?
          : null,
    );
  }
}

class RecapItem {
  final int id;
  final int meetingId;
  final String createdBy;
  final String content;
  final bool isPublic;
  final DateTime? createdAt;

  RecapItem({
    required this.id,
    required this.meetingId,
    required this.createdBy,
    required this.content,
    required this.isPublic,
    required this.createdAt,
  });

  factory RecapItem.fromJson(Map<String, dynamic> json) {
    return RecapItem(
      id: json['id'] as int,
      meetingId: json['meeting_id'] as int,
      createdBy: json['created_by'] as String,
      content: (json['content'] ?? '') as String,
      isPublic: (json['is_public'] ?? false) as bool,
      createdAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

/// ======================================================
/// Auth Gate
/// ======================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    if (session == null) {
      return const LoginScreen();
    }
    return const ProfileBootstrapScreen();
  }
}

/// ======================================================
/// Login Screen
/// ======================================================

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
      _toast('회원가입 완료');
    } on AuthException catch (e) {
      _toast('회원가입 실패: ${e.message}');
    } catch (e) {
      _toast('회원가입 실패: $e');
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
        MaterialPageRoute(builder: (_) => const ProfileBootstrapScreen()),
      );
    } on AuthException catch (e) {
      _toast('로그인 실패: ${e.message}');
    } catch (e) {
      _toast('로그인 실패: $e');
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
      _toast('${acc.label} 로그인 완료');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileBootstrapScreen()),
      );
    } on AuthException catch (e) {
      _toast('빠른 로그인 실패: ${e.message}');
    } catch (e) {
      _toast('빠른 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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

/// ======================================================
/// Profile Bootstrap
/// ======================================================

class ProfileBootstrapScreen extends StatefulWidget {
  const ProfileBootstrapScreen({super.key});

  @override
  State<ProfileBootstrapScreen> createState() => _ProfileBootstrapScreenState();
}

class _ProfileBootstrapScreenState extends State<ProfileBootstrapScreen> {
  final _nickname = TextEditingController();
  bool _loading = true;
  String? _currentNick;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        await supabase.auth.signOut();
        return;
      }

      final row =
          await supabase.from('users').select('nickname').eq('id', uid).maybeSingle();

      final nick = row?['nickname'] as String?;
      _currentNick = nick;

      if (nick != null && nick.trim().isNotEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MeetingsListScreen()),
        );
      }
    } catch (e) {
      _toast('프로필 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNickname() async {
    final nick = _nickname.text.trim();
    if (nick.isEmpty) {
      _toast('닉네임을 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser!.id;

      await supabase.from('users').upsert({
        'id': uid,
        'nickname': nick,
      });

      _toast('닉네임 저장 완료');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MeetingsListScreen()),
      );
    } catch (e) {
      _toast('닉네임 저장 실패: $e');
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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
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
                  const Text('독서모임에서 사용할 닉네임을 입력해 주세요.'),
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

/// ======================================================
/// Meetings List
/// ======================================================

class MeetingsListScreen extends StatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen> {
  bool _loading = true;
  List<MeetingModel> _meetings = [];

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('meetings')
          .select('''
            id,
            host_id,
            book_id,
            title,
            meeting_date,
            location,
            max_participants,
            status,
            host_reason,
            created_at,
            books (
              id,
              isbn,
              title,
              author,
              cover_url,
              category
            )
          ''')
          .order('meeting_date', ascending: true);

      _meetings = (rows as List)
          .map((e) => MeetingModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _toast('모임 목록 조회 실패: $e');
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

  Future<void> _switchTo(TestAccount acc) async {
    try {
      await supabase.auth.signOut();
      await supabase.auth.signInWithPassword(
        email: acc.email.trim().toLowerCase(),
        password: acc.password.trim(),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProfileBootstrapScreen()),
        (_) => false,
      );
    } on AuthException catch (e) {
      _toast('계정 전환 실패: ${e.message}');
    } catch (e) {
      _toast('계정 전환 실패: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmtDate(DateTime dt) {
    final v = dt.toLocal();
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('독서모임 리스트'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyLibraryScreen()),
              );
            },
            icon: const Icon(Icons.library_books),
            tooltip: '내 라이브러리',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.switch_account),
            onSelected: (v) async {
              if (v == 'logout') {
                await _signOut();
                return;
              }
              final acc = kTestAccounts.firstWhere((a) => a.label == v);
              await _switchTo(acc);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              const PopupMenuDivider(),
              ...kTestAccounts.map(
                (a) => PopupMenuItem(value: a.label, child: Text('${a.label}로 전환')),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? const Center(child: Text('등록된 모임이 없습니다. 호스트가 모임을 만들어 주세요.'))
              : RefreshIndicator(
                  onRefresh: _loadMeetings,
                  child: ListView.builder(
                    itemCount: _meetings.length,
                    itemBuilder: (context, i) {
                      final m = _meetings[i];
                      final isHost = currentUid != null && currentUid == m.hostId;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(m.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.book != null)
                                Text('책: ${m.book!.title} / ${m.book!.author ?? "-"}'),
                              Text('일시: ${_fmtDate(m.meetingDate)}'),
                              Text('장소: ${m.location ?? "-"}'),
                              Text('상태: ${m.status}'),
                              if (m.hostReason != null &&
                                  m.hostReason!.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('선정 이유: ${m.hostReason!}'),
                              ],
                              if (isHost)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    '호스트',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MeetingDetailScreen(meeting: m),
                              ),
                            );
                            _loadMeetings();
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
          );
          _loadMeetings();
        },
        label: const Text('모임 만들기'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

/// ======================================================
/// Create Meeting
/// ======================================================

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _searchController = TextEditingController();

  final _isbn = TextEditingController();
  final _bookTitle = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();

  final _meetingTitle = TextEditingController();
  final _location = TextEditingController();
  final _maxParticipants = TextEditingController(text: '5');
  final _hostReason = TextEditingController();

  bool _loading = false;
  bool _searching = false;
  bool _reasonLoading = false;
  bool _descriptionLoading = false;

  DateTime _meetingDate = DateTime.now().add(const Duration(days: 1));

  List<BookSearchResult> _searchResults = [];
  BookSearchResult? _selectedBook;

  Future<void> _searchBooks() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      _toast('검색어를 입력하세요.');
      return;
    }

    setState(() => _searching = true);

    try {
      final url = Uri.parse('$apiBaseUrl/books/search?q=${Uri.encodeQueryComponent(q)}');
      final res = await http.get(url);

      if (res.statusCode != 200) {
        _toast('책 검색 실패: ${res.statusCode} ${res.body}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final books = (data['books'] as List)
          .map((e) => BookSearchResult.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        _searchResults = books;
      });
    } catch (e) {
      _toast('책 검색 실패: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectBook(BookSearchResult book) {
    setState(() {
      _selectedBook = book;
      _isbn.text = book.isbn;
      _bookTitle.text = book.title;
      _author.text = book.author;
      _description.text = book.description.trim();
    });
  }

  Future<void> _generateBookDescription() async {
    if (_selectedBook == null) {
      _toast('먼저 책을 선택하세요.');
      return;
    }

    setState(() => _descriptionLoading = true);

    try {
      final url = Uri.parse('$apiBaseUrl/books/generate-description');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _bookTitle.text.trim(),
          'author': _author.text.trim(),
          'publisher': _selectedBook?.publisher ?? '',
          'publishedDate': _selectedBook?.publishedDate ?? '',
        }),
      );

      if (res.statusCode != 200) {
        _toast('책 소개 생성 실패: ${res.statusCode} ${res.body}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final generated = (data['description'] ?? '').toString().trim();

      setState(() {
        _description.text = generated;
      });
    } catch (e) {
      _toast('책 소개 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _descriptionLoading = false);
    }
  }

  Future<void> _generateReason() async {
    if (_selectedBook == null) {
      _toast('먼저 책을 선택하세요.');
      return;
    }

    setState(() => _reasonLoading = true);

    try {
      final url = Uri.parse('$apiBaseUrl/books/generate-reason');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _bookTitle.text.trim(),
          'author': _author.text.trim(),
          'description': _description.text.trim(),
        }),
      );

      if (res.statusCode != 200) {
        _toast('선정 이유 생성 실패: ${res.statusCode} ${res.body}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _hostReason.text = (data['reason'] ?? '').toString();
      });
    } catch (e) {
      _toast('선정 이유 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _reasonLoading = false);
    }
  }

  Future<int> _findOrCreateBook() async {
    final isbn = _isbn.text.trim();
    final title = _bookTitle.text.trim();
    final author = _author.text.trim();
    final description = _description.text.trim();
    final coverUrl = _selectedBook?.coverUrl;

    if (isbn.isEmpty || title.isEmpty) {
      throw Exception('책을 검색 후 선택해 주세요.');
    }

    final existing =
        await supabase.from('books').select('id').eq('isbn', isbn).maybeSingle();

    if (existing != null) {
      final existingId = existing['id'] as int;

      await supabase.from('books').update({
        'title': title,
        'author': author.isEmpty ? null : author,
        'cover_url': coverUrl,
        'description': description.isEmpty ? null : description,
      }).eq('id', existingId);

      return existingId;
    }

    final inserted = await supabase
        .from('books')
        .insert({
          'isbn': isbn,
          'title': title,
          'author': author.isEmpty ? null : author,
          'cover_url': coverUrl,
          'description': description.isEmpty ? null : description,
        })
        .select('id')
        .single();

    return inserted['id'] as int;
  }

  Future<void> _saveMeeting() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      _toast('로그인이 필요합니다.');
      return;
    }

    final meetingTitle = _meetingTitle.text.trim();
    final location = _location.text.trim();
    final maxParticipants = int.tryParse(_maxParticipants.text.trim()) ?? 5;
    final hostReason = _hostReason.text.trim();

    if (_selectedBook == null) {
      _toast('책을 검색하고 선택하세요.');
      return;
    }

    if (meetingTitle.isEmpty) {
      _toast('모임 제목을 입력하세요.');
      return;
    }

    setState(() => _loading = true);

    try {
      final bookId = await _findOrCreateBook();

      await supabase.from('meetings').insert({
        'host_id': uid,
        'book_id': bookId,
        'title': meetingTitle,
        'meeting_date': _meetingDate.toUtc().toIso8601String(),
        'location': location.isEmpty ? null : location,
        'max_participants': maxParticipants,
        'status': 'open',
        'host_reason': hostReason.isEmpty ? null : hostReason,
      });

      _toast('모임이 생성되었습니다.');

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _toast('모임 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _meetingDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isbn.dispose();
    _bookTitle.dispose();
    _author.dispose();
    _description.dispose();
    _meetingTitle.dispose();
    _location.dispose();
    _maxParticipants.dispose();
    _hostReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모임 만들기'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('1. 책 검색'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: '책 제목 검색',
                    hintText: '예: 작별하지 않는다',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _searching ? null : _searchBooks,
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('검색'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_searchResults.isNotEmpty) ...[
            const Text('검색 결과'),
            const SizedBox(height: 8),
            ..._searchResults.map(
              (book) => Card(
                child: ListTile(
                  leading: book.coverUrl.isNotEmpty
                      ? Image.network(book.coverUrl, width: 40, fit: BoxFit.cover)
                      : const Icon(Icons.menu_book),
                  title: Text(book.title),
                  subtitle: Text('${book.author}\nISBN: ${book.isbn}'),
                  isThreeLine: true,
                  onTap: () => _selectBook(book),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text('2. 선택한 책 정보'),
          const SizedBox(height: 12),
          if (_selectedBook != null && _selectedBook!.coverUrl.isNotEmpty)
            Center(
              child: Image.network(
                _selectedBook!.coverUrl,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _bookTitle,
            readOnly: true,
            decoration: const InputDecoration(labelText: '책 제목'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _author,
            readOnly: true,
            decoration: const InputDecoration(labelText: '저자'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _isbn,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'ISBN'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '책 소개',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _descriptionLoading ? null : _generateBookDescription,
                  icon: const Icon(Icons.auto_awesome),
                  label: _descriptionLoading
                      ? const Text('생성 중...')
                      : const Text('자동생성'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '책 소개를 입력하거나 자동생성을 눌러주세요.',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          const Text('3. 모임 정보'),
          const SizedBox(height: 12),
          TextField(
            controller: _meetingTitle,
            decoration: const InputDecoration(labelText: '모임 제목'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: '장소'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxParticipants,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '최대 인원'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('모임 일시'),
            subtitle: Text(_fmtDate(_meetingDate)),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDateTime,
          ),



          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '4. 선정 이유',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _reasonLoading ? null : _generateReason,
                  icon: const Icon(Icons.auto_awesome),
                  label: _reasonLoading
                      ? const Text('생성 중...')
                      : const Text('자동생성'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hostReason,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '선정 이유를 입력하거나 자동생성을 눌러주세요.',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _saveMeeting,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('모임 저장'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ======================================================
/// Meeting Detail
/// ======================================================

class MeetingDetailScreen extends StatefulWidget {
  final MeetingModel meeting;

  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  bool _loadingQuestions = false;
  bool _loadingParticipants = false;
  bool _loadingRecap = false;
  bool _loadingRecaps = false;

  List<QuestionItem> _questions = [];
  List<ParticipantItem> _requestedParticipants = [];
  List<RecapItem> _recaps = [];
  String? _myParticipantStatus;

  bool get _isHost => supabase.auth.currentUser?.id == widget.meeting.hostId;
  bool get _isApprovedParticipant => _myParticipantStatus == 'approved';
  bool get _canViewQuestions => _isHost || _isApprovedParticipant;
  bool get _canRequestJoin =>
      !_isHost && (_myParticipantStatus == null || _myParticipantStatus == 'rejected');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMyParticipantStatus(),
      _loadQuestions(),
      _loadRecaps(),
      if (_isHost) _loadRequestedParticipants(),
    ]);
  }

  Future<void> _loadMyParticipantStatus() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final row = await supabase
          .from('meeting_participants')
          .select('status')
          .eq('meeting_id', widget.meeting.id)
          .eq('user_id', uid)
          .maybeSingle();

      setState(() {
        _myParticipantStatus = row?['status'] as String?;
      });
    } catch (e) {
      _toast('참여 상태 조회 실패: $e');
    }
  }

  Future<void> _loadRequestedParticipants() async {
    setState(() => _loadingParticipants = true);
    try {
      final rows = await supabase
          .from('meeting_participants')
          .select('''
            id,
            meeting_id,
            user_id,
            status,
            requested_at,
            approved_at,
            users (
              nickname
            )
          ''')
          .eq('meeting_id', widget.meeting.id)
          .eq('status', 'requested')
          .order('requested_at', ascending: true);

      _requestedParticipants = (rows as List)
          .map((e) => ParticipantItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _toast('신청자 목록 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingParticipants = false);
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _loadingQuestions = true);
    try {
      final url = Uri.parse('$apiBaseUrl/meetings/${widget.meeting.id}/questions');
      final res = await http.get(url);

      if (res.statusCode != 200) {
        _toast('질문 조회 실패: ${res.statusCode} ${res.body}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final questions = (data['questions'] as List)
          .map((e) => QuestionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() => _questions = questions);
    } catch (e) {
      _toast('질문 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _loadRecaps() async {
    setState(() => _loadingRecaps = true);
    try {
      final url = Uri.parse('$apiBaseUrl/meetings/${widget.meeting.id}/recaps');
      final res = await http.get(url);

      if (res.statusCode != 200) {
        _toast('요약 조회 실패: ${res.statusCode}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final recaps = (data['recaps'] as List)
          .map((e) => RecapItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() => _recaps = recaps);
    } catch (e) {
      _toast('요약 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingRecaps = false);
    }
  }

  Future<void> _requestJoin() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      _toast('로그인이 필요합니다.');
      return;
    }

    try {
      await supabase.from('meeting_participants').upsert({
        'meeting_id': widget.meeting.id,
        'user_id': uid,
        'status': 'requested',
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      });

      _toast('참여 신청이 완료되었습니다.');
      await _loadMyParticipantStatus();
    } catch (e) {
      _toast('참여 신청 실패: $e');
    }
  }

  Future<void> _approveParticipant(ParticipantItem p) async {
    try {
      await supabase.from('meeting_participants').update({
        'status': 'approved',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', p.id);

      _toast('승인 완료');
      await _loadRequestedParticipants();
    } catch (e) {
      _toast('승인 실패: $e');
    }
  }

  Future<void> _rejectParticipant(ParticipantItem p) async {
    try {
      await supabase
          .from('meeting_participants')
          .update({'status': 'rejected'}).eq('id', p.id);

      _toast('거절 완료');
      await _loadRequestedParticipants();
    } catch (e) {
      _toast('거절 실패: $e');
    }
  }

  Future<void> _generateQuestions() async {
    if (!_isHost) {
      _toast('호스트만 질문을 생성할 수 있습니다.');
      return;
    }

    final book = widget.meeting.book;
    if (book == null) {
      _toast('책 정보가 없습니다.');
      return;
    }

    setState(() => _loadingQuestions = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        _toast('로그인이 필요합니다.');
        return;
      }

      final url = Uri.parse('$apiBaseUrl/generate-questions');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'meetingId': widget.meeting.id,
          'bookTitle': book.title,
          'author': book.author ?? '',
          'hostUserId': currentUser.id,
        }),
      );

      if (res.statusCode != 200) {
        _toast('질문 생성 실패: ${res.statusCode} ${res.body}');
        return;
      }

      _toast('질문 생성 완료');
      await _loadQuestions();
    } catch (e) {
      _toast('질문 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _addQuestion() async {
    if (!_isHost) {
      _toast('호스트만 질문을 추가할 수 있습니다.');
      return;
    }

    final controller = TextEditingController();

    final questionText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('질문 추가'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '추가할 질문을 입력하세요.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (questionText == null) return;
    if (questionText.isEmpty) {
      _toast('질문을 입력하세요.');
      return;
    }

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        _toast('로그인이 필요합니다.');
        return;
      }

      await supabase.from('questions').insert({
        'meeting_id': widget.meeting.id,
        'created_by': uid,
        'question': questionText,
      });

      _toast('질문이 추가되었습니다.');
      await _loadQuestions();
    } catch (e) {
      _toast('질문 추가 실패: $e');
    }
  }

  Future<void> _editQuestion(QuestionItem q) async {
    if (!_isHost) {
      _toast('호스트만 질문을 수정할 수 있습니다.');
      return;
    }

    final controller = TextEditingController(text: q.question);

    final updatedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('질문 수정'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '질문을 입력하세요.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (updatedText == null) return;
    if (updatedText.isEmpty) {
      _toast('질문을 입력하세요.');
      return;
    }

    try {
      await supabase.from('questions').update({
        'question': updatedText,
      }).eq('id', q.id);

      _toast('질문 수정 완료');
      await _loadQuestions();
    } catch (e) {
      _toast('질문 수정 실패: $e');
    }
  }

  Future<void> _generateRecap() async {
    if (!_isHost) {
      _toast('호스트만 요약을 생성할 수 있습니다.');
      return;
    }

    setState(() => _loadingRecap = true);
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        _toast('로그인이 필요합니다.');
        return;
      }

      final url = Uri.parse('$apiBaseUrl/meetings/${widget.meeting.id}/generate-recap');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hostUserId': currentUser.id,
        }),
      );

      if (res.statusCode != 200) {
        _toast('요약 생성 실패: ${res.statusCode} ${res.body}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final recapJson = Map<String, dynamic>.from(data['recap']);
      final recap = RecapItem.fromJson(recapJson);

      _toast('AI 요약 생성 완료');
      await _loadRecaps();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecapDetailScreen(recap: recap),
        ),
      );
    } catch (e) {
      _toast('요약 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingRecap = false);
    }
  }

  Future<void> _openLatestRecap() async {
    await _loadRecaps();
    if (_recaps.isEmpty) {
      _toast('생성된 AI 요약이 없습니다.');
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecapDetailScreen(recap: _recaps.first),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmtDate(DateTime dt) {
    final v = dt.toLocal();
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final book = m.book;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (book != null) ...[
            Text(
              book.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('저자: ${book.author ?? "-"}'),
            Text('ISBN: ${book.isbn}'),
            const SizedBox(height: 16),
          ],
          Text('모임 제목: ${m.title}'),
          const SizedBox(height: 4),
          Text('일시: ${_fmtDate(m.meetingDate)}'),
          if (m.hostReason != null && m.hostReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('선정 이유: ${m.hostReason!}'),
          ],
          Text('장소: ${m.location ?? "-"}'),
          Text('상태: ${m.status}'),
          const SizedBox(height: 8),
          if (_isHost)
            const Text(
              '현재 로그인 사용자는 이 모임의 호스트입니다.',
              style: TextStyle(fontWeight: FontWeight.bold),
            )
          else
            Text('내 참여 상태: ${_myParticipantStatus ?? "미신청"}'),
          const SizedBox(height: 16),

          if (!_isHost) ...[
            if (_canRequestJoin)
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _requestJoin,
                  child: const Text('참여 신청'),
                ),
              )
            else if (_myParticipantStatus == 'requested')
              const Text('승인 대기중입니다.')
            else if (_myParticipantStatus == 'approved')
              const Text('이 모임에 참여 중입니다.'),
            const SizedBox(height: 24),
          ],

          if (_isHost) ...[
            const Text(
              '참여 신청자',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loadingParticipants)
              const Center(child: CircularProgressIndicator())
            else if (_requestedParticipants.isEmpty)
              const Text('대기 중인 신청자가 없습니다.')
            else
              ..._requestedParticipants.map(
                (p) => Card(
                  child: ListTile(
                    title: Text(p.nickname ?? p.userId),
                    subtitle: Text(
                      '신청일: ${p.requestedAt != null ? _fmtDate(p.requestedAt!) : "-"}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _approveParticipant(p),
                          child: const Text('승인'),
                        ),
                        TextButton(
                          onPressed: () => _rejectParticipant(p),
                          child: const Text('거절'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],

          Row(
            children: [
              const Expanded(
                child: Text(
                  'AI 요약',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isHost && !_loadingRecap ? _generateRecap : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: _loadingRecap
                        ? const Text('생성 중...')
                        : const Text('생성'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _loadingRecaps ? null : _openLatestRecap,
                    icon: const Icon(Icons.article),
                    label: Text(_recaps.isEmpty ? '보기' : '보기 (${_recaps.length})'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '토론 질문',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _loadingQuestions ? null : _loadQuestions,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (!_canViewQuestions && !_isHost)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('질문은 승인된 참여자와 호스트만 볼 수 있습니다.'),
            )
          else if (_loadingQuestions)
            const Center(child: CircularProgressIndicator())
          else if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('등록된 질문이 없습니다.')),
            )
          else
            ..._questions.map(
              (q) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(q.question),
                  subtitle: q.createdAt != null
                      ? Text('생성일: ${_fmtDate(q.createdAt!)}')
                      : null,
                  trailing: _isHost
                      ? IconButton(
                          onPressed: () => _editQuestion(q),
                          icon: const Icon(Icons.edit),
                          tooltip: '질문 수정',
                        )
                      : null,
                  onTap: _canViewQuestions || _isHost
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuestionDetailScreen(
                                meeting: m,
                                question: q,
                                isHost: _isHost,
                                canAnswer: _isHost || _isApprovedParticipant,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isHost
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'generate_questions',
                  onPressed: _loadingQuestions ? null : _generateQuestions,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI 질문 생성'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'add_question',
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('질문 추가'),
                ),
              ],
            )
          : null,
    );
  }
}

/// ======================================================
/// Question Detail
/// ======================================================

class QuestionDetailScreen extends StatefulWidget {
  final MeetingModel meeting;
  final QuestionItem question;
  final bool isHost;
  final bool canAnswer;

  const QuestionDetailScreen({
    super.key,
    required this.meeting,
    required this.question,
    required this.isHost,
    required this.canAnswer,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  final _answerController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  List<AnswerItem> _answers = [];
  AnswerItem? _myAnswer;

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('answers')
          .select('''
            id,
            question_id,
            meeting_id,
            user_id,
            answer,
            created_at,
            users (
              nickname
            )
          ''')
          .eq('question_id', widget.question.id)
          .order('created_at', ascending: true);

      final answers = (rows as List)
          .map((e) => AnswerItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final myUid = supabase.auth.currentUser?.id;
      final myAnswer = answers
          .where((a) => a.userId == myUid)
          .cast<AnswerItem?>()
          .firstWhere((a) => a != null, orElse: () => null);

      _answers = answers;
      _myAnswer = myAnswer;
      _answerController.text = myAnswer?.answer ?? '';
    } catch (e) {
      _toast('답변 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAnswer() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      _toast('로그인이 필요합니다.');
      return;
    }
    if (!widget.canAnswer) {
      _toast('승인된 참여자만 답변을 작성할 수 있습니다.');
      return;
    }

    final text = _answerController.text.trim();
    if (text.isEmpty) {
      _toast('답변을 입력하세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_myAnswer == null) {
        await supabase.from('answers').insert({
          'question_id': widget.question.id,
          'meeting_id': widget.meeting.id,
          'user_id': uid,
          'answer': text,
        });
      } else {
        await supabase
            .from('answers')
            .update({'answer': text}).eq('id', _myAnswer!.id);
      }

      _toast('답변 저장 완료');
      await _loadAnswers();
    } catch (e) {
      _toast('답변 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmtDate(DateTime dt) {
    final v = dt.toLocal();
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.canAnswer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('질문 상세'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.question.question,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (canWrite) ...[
                  TextField(
                    controller: _answerController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '한줄 답변',
                      border: OutlineInputBorder(),
                      hintText: '답변을 입력하세요.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveAnswer,
                      child: _saving
                          ? const CircularProgressIndicator()
                          : const Text('답변 저장'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  const Text('답변 작성 권한이 없습니다.'),
                  const SizedBox(height: 24),
                ],
                const Text(
                  '답변 목록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_answers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('아직 등록된 답변이 없습니다.'),
                  )
                else
                  ..._answers.map(
                    (a) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(a.nickname ?? a.userId),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.answer),
                            if (a.createdAt != null)
                              Text(
                                _fmtDate(a.createdAt!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// ======================================================
/// My Library Screen
/// ======================================================

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  bool _loading = true;
  List<MeetingModel> _meetings = [];

  @override
  void initState() {
    super.initState();
    _loadLibraryMeetings();
  }

  Future<void> _loadLibraryMeetings() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        _toast('로그인이 필요합니다.');
        return;
      }

      final hostedRows = await supabase
          .from('meetings')
          .select('''
            id,
            host_id,
            book_id,
            title,
            meeting_date,
            location,
            max_participants,
            status,
            host_reason,
            created_at,
            books (
              id,
              isbn,
              title,
              author,
              cover_url,
              category
            )
          ''')
          .eq('host_id', uid);

      final participantRows = await supabase
          .from('meeting_participants')
          .select('meeting_id')
          .eq('user_id', uid)
          .eq('status', 'approved');

      final participantMeetingIds =
          (participantRows as List).map((e) => e['meeting_id'] as int).toSet().toList();

      List<dynamic> approvedRows = [];
      if (participantMeetingIds.isNotEmpty) {
        approvedRows = await supabase
            .from('meetings')
            .select('''
              id,
              host_id,
              book_id,
              title,
              meeting_date,
              location,
              max_participants,
              status,
              host_reason,
              created_at,
              books (
                id,
                isbn,
                title,
                author,
                cover_url,
                category
              )
            ''')
            .inFilter('id', participantMeetingIds);
      }

      final map = <int, MeetingModel>{};

      for (final row in hostedRows as List) {
        final m = MeetingModel.fromJson(Map<String, dynamic>.from(row));
        map[m.id] = m;
      }

      for (final row in approvedRows) {
        final m = MeetingModel.fromJson(Map<String, dynamic>.from(row));
        map[m.id] = m;
      }

      final list = map.values.toList()
        ..sort((a, b) => b.meetingDate.compareTo(a.meetingDate));

      _meetings = list;
    } catch (e) {
      _toast('내 라이브러리 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmtDate(DateTime dt) {
    final v = dt.toLocal();
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 라이브러리'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? const Center(child: Text('참여 중이거나 호스트인 모임이 없습니다.'))
              : RefreshIndicator(
                  onRefresh: _loadLibraryMeetings,
                  child: ListView.builder(
                    itemCount: _meetings.length,
                    itemBuilder: (context, i) {
                      final m = _meetings[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(m.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.book != null)
                                Text('책: ${m.book!.title} / ${m.book!.author ?? "-"}'),
                              Text('일시: ${_fmtDate(m.meetingDate)}'),
                              Text('상태: ${m.status}'),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LibraryMeetingDetailScreen(meeting: m),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// ======================================================
/// Library Meeting Detail
/// ======================================================

class LibraryMeetingDetailScreen extends StatefulWidget {
  final MeetingModel meeting;

  const LibraryMeetingDetailScreen({super.key, required this.meeting});

  @override
  State<LibraryMeetingDetailScreen> createState() =>
      _LibraryMeetingDetailScreenState();
}

class _LibraryMeetingDetailScreenState extends State<LibraryMeetingDetailScreen> {
  bool _loading = true;
  List<AnswerItem> _myAnswers = [];
  List<RecapItem> _recaps = [];

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
        _toast('로그인이 필요합니다.');
        return;
      }

      final answerRows = await supabase
          .from('answers')
          .select('''
            id,
            question_id,
            meeting_id,
            user_id,
            answer,
            created_at,
            users (
              nickname
            ),
            questions (
              question
            )
          ''')
          .eq('meeting_id', widget.meeting.id)
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      _myAnswers = (answerRows as List)
          .map((e) => AnswerItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final recapUrl = Uri.parse('$apiBaseUrl/meetings/${widget.meeting.id}/recaps');
      final recapRes = await http.get(recapUrl);

      if (recapRes.statusCode == 200) {
        final data = jsonDecode(recapRes.body) as Map<String, dynamic>;
        _recaps = (data['recaps'] as List)
            .map((e) => RecapItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _toast('요약 조회 실패: ${recapRes.statusCode}');
      }
    } catch (e) {
      _toast('라이브러리 상세 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _fmtDate(DateTime dt) {
    final v = dt.toLocal();
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final book = m.book;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (book != null) ...[
                  Text(
                    book.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('저자: ${book.author ?? "-"}'),
                  const SizedBox(height: 16),
                ],
                const Text(
                  '내 답변',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_myAnswers.isEmpty)
                  const Text('내가 작성한 답변이 없습니다.')
                else
                  ..._myAnswers.map(
                    (a) => Card(
                      child: ListTile(
                        title: Text(a.questionText ?? '질문'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.answer),
                            if (a.createdAt != null)
                              Text(
                                _fmtDate(a.createdAt!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'AI 요약 리스트',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_recaps.isEmpty)
                  const Text('아직 생성된 요약이 없습니다.')
                else
                  ..._recaps.map(
                    (r) => Card(
                      child: ListTile(
                        title: Text(
                          r.content.length > 60
                              ? '${r.content.substring(0, 60)}...'
                              : r.content,
                        ),
                        subtitle:
                            r.createdAt != null ? Text(_fmtDate(r.createdAt!)) : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecapDetailScreen(recap: r),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// ======================================================
/// Recap Detail
/// ======================================================

class RecapDetailScreen extends StatelessWidget {
  final RecapItem recap;

  const RecapDetailScreen({super.key, required this.recap});

  String _fmtDate(DateTime dt) {
    final v = dt.toLocal();
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 요약 상세'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            if (recap.createdAt != null)
              Text(
                _fmtDate(recap.createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Text(recap.content),
          ],
        ),
      ),
    );
  }
}