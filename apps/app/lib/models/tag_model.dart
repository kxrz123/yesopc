class ApiTag {
  final String id;
  final String name;
  final DateTime createdAt;

  ApiTag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory ApiTag.fromJson(Map<String, dynamic> json) {
    return ApiTag(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

