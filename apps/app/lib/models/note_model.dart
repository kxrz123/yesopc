class ApiNote {
  final String id;
  final String contentText;
  final String visibility; // public | private
  final String author;
  final DateTime createdAt;

  ApiNote({
    required this.id,
    required this.contentText,
    required this.visibility,
    required this.author,
    required this.createdAt,
  });

  factory ApiNote.fromJson(Map<String, dynamic> json) {
    return ApiNote(
      id: json['id']?.toString() ?? '',
      contentText: json['content_text']?.toString() ?? '',
      visibility: json['visibility']?.toString() ?? 'public',
      author: json['author']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

