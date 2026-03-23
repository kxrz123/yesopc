class ApiArticle {
  final String id;
  final String title;
  final String bodyHtml;
  final String coverImage;
  final String status; // draft | published
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final int readCount;
  final String authorId;
  final String author;
  final String summary;
  final String authorDisplay;
  final bool isOriginal;

  ApiArticle({
    required this.id,
    required this.title,
    required this.bodyHtml,
    required this.coverImage,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.readCount,
    this.authorId = '',
    required this.author,
    this.summary = '',
    this.authorDisplay = '',
    this.isOriginal = false,
  });

  factory ApiArticle.fromJson(Map<String, dynamic> json) {
    return ApiArticle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      bodyHtml: json['body_html']?.toString() ?? '',
      coverImage: json['cover_image']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      publishedAt: json['published_at'] == null || json['published_at'].toString().isEmpty
          ? null
          : DateTime.parse(json['published_at'].toString()),
      readCount: (json['read_count'] as num?)?.toInt() ?? 0,
      authorId: json['author_id']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
      author: json['author']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      authorDisplay: json['author_display']?.toString() ?? '',
      isOriginal: json['is_original'] == true,
    );
  }
}

