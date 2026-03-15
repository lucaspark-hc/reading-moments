import 'book_model.dart';

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

  final String? participationStatus; // pending, approved, rejected
  final bool isHost;
  final String? badgeText;

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
    required this.participationStatus,
    required this.isHost,
    required this.badgeText,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    final dynamic bookJson = json['books'];

    return MeetingModel(
      id: json['id'] as int,
      hostId: json['host_id'] as String?,
      bookId: json['book_id'] as int?,
      title: (json['title'] ?? '') as String,
      meetingDate: DateTime.parse(json['meeting_date'] as String),
      location: json['location'] as String?,
      maxParticipants: (json['max_participants'] ?? 5) as int,
      status: (json['status'] ?? 'open') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      book: bookJson is Map<String, dynamic>
          ? BookModel.fromJson(bookJson)
          : null,
      hostReason: json['host_reason'] as String?,
      participationStatus: json['participation_status'] as String?,
      isHost: (json['is_host'] ?? false) as bool,
      badgeText: json['badge_text'] as String?,
    );
  }

  MeetingModel copyWith({
    int? id,
    String? hostId,
    int? bookId,
    String? title,
    DateTime? meetingDate,
    String? location,
    int? maxParticipants,
    String? status,
    DateTime? createdAt,
    BookModel? book,
    String? hostReason,
    String? participationStatus,
    bool? isHost,
    String? badgeText,
  }) {
    return MeetingModel(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      meetingDate: meetingDate ?? this.meetingDate,
      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      book: book ?? this.book,
      hostReason: hostReason ?? this.hostReason,
      participationStatus: participationStatus ?? this.participationStatus,
      isHost: isHost ?? this.isHost,
      badgeText: badgeText ?? this.badgeText,
    );
  }
}
