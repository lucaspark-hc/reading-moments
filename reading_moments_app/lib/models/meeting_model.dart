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
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      book: bookJson is Map<String, dynamic>
          ? BookModel.fromJson(bookJson)
          : null,
      hostReason: json['host_reason'] as String?,
    );
  }
}