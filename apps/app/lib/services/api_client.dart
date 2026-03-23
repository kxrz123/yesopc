import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../constants.dart';
import '../models/article_model.dart';
import '../models/note_model.dart';
import '../models/tag_model.dart';
import 'session_service.dart';

class LoginResult {
  final String token;
  final String userId;
  final String username;

  const LoginResult({
    required this.token,
    required this.userId,
    required this.username,
  });
}

class ApiClient {
  final String baseUrl;
  final SessionService _session;

  ApiClient({this.baseUrl = apiBaseUrl, SessionService? session})
      : _session = session ?? SessionService.instance;

  String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) return trimmed.substring(0, trimmed.length - 1);
    return trimmed;
  }

  String _url(String path) {
    final normalized = _normalizeBaseUrl(baseUrl);
    return '$normalized$path';
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final h = <String, String>{};
    if (json) {
      h['Content-Type'] = 'application/json; charset=utf-8';
    }
    final t = _session.token;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<LoginResult> login({required String username, required String password}) async {
    final loginUri = _url('/api/v1/auth/login');
    final res = await http
        .post(
          Uri.parse(loginUri),
          headers: await _headers(),
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception(_errBody(res, requestUrl: loginUri));
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final user = m['user'] as Map<String, dynamic>? ?? {};
    return LoginResult(
      token: m['token'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? username,
    );
  }

  Future<void> register({required String username, required String password}) async {
    final registerUri = _url('/api/v1/auth/register');
    final res = await http
        .post(
          Uri.parse(registerUri),
          headers: await _headers(),
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 201) {
      throw Exception(_errBody(res, requestUrl: registerUri));
    }
  }

  Future<void> logout() async {
    try {
      await http
          .post(
            Uri.parse(_url('/api/v1/auth/logout')),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 8));
    } finally {
      await _session.clearSession();
    }
  }

  String _errBody(http.Response res, {String? requestUrl}) {
    try {
      final m = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = m?['error'] ?? m?['message'] ?? m?['msg'];
      if (msg != null) {
        return _with404Hint('$msg', res.statusCode, requestUrl);
      }
    } catch (_) {}
    return _with404Hint('请求失败: ${res.statusCode} ${res.body}', res.statusCode, requestUrl);
  }

  String _with404Hint(String base, int status, String? requestUrl) {
    if (status != 404 || requestUrl == null) return base;
    final root = _normalizeBaseUrl(baseUrl);
    return '$base\n\n'
        '若出现 404：① 在本机重新编译并重启 content-api（终端会打印 Routes 含 POST /api/v1/auth/login）；'
        '② 用浏览器打开 $root/ 应看到 service=yesopc-content-api；若仍是 404，说明 IP 不是跑后端的电脑（换 WiFi 后请用 ipconfig 查新 IP）。'
        '\n当前请求: $requestUrl';
  }

  Future<List<ApiTag>> listTags() async {
    final res = await http
        .get(Uri.parse(_url('/api/v1/tags')), headers: await _headers(json: false))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('拉取 tags 失败: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => ApiTag.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [mine] 为 true 时拉取当前用户全部备忘录（含 private）；
  /// [authorId] 可拉取指定用户公开备忘录（个人主页）。
  Future<List<ApiNote>> listNotes({bool mine = false, String? authorId}) async {
    final qp = <String, String>{};
    if (mine) qp['mine'] = '1';
    if (authorId != null && authorId.isNotEmpty) qp['author_id'] = authorId;
    final path = Uri.parse(_url('/api/v1/notes')).replace(queryParameters: qp.isEmpty ? null : qp).toString();
    final res = await http.get(Uri.parse(path), headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('拉取 notes 失败: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => ApiNote.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createNote({
    required String contentText,
    String visibility = 'public',
  }) async {
    final res = await http
        .post(
          Uri.parse(_url('/api/v1/notes')),
          headers: await _headers(),
          body: jsonEncode({
            'content_text': contentText,
            'visibility': visibility,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 201) {
      throw Exception('保存 note 失败: ${res.statusCode} ${res.body}');
    }
  }

  Future<Map<String, dynamic>> _decodeJson(http.Response res) async {
    if (res.body.isEmpty) return const {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<ListArticlesResp> listArticles({
    required String status,
    required int page,
    required int pageSize,
    String? authorId,
  }) async {
    final qp = <String, String>{
      'status': status,
      'page': '$page',
      'page_size': '$pageSize',
    };
    if (authorId != null && authorId.isNotEmpty) {
      qp['author_id'] = authorId;
    }
    final uri = Uri.parse(_url('/api/v1/articles')).replace(queryParameters: qp);

    final res = await http.get(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('拉取 articles 失败: ${res.statusCode} ${res.body}');
    }

    final decoded = await _decodeJson(res);
    final itemsJson = (decoded['items'] as List<dynamic>? ?? const []);
    final items = itemsJson.map((e) => ApiArticle.fromJson(e as Map<String, dynamic>)).toList();

    return ListArticlesResp(
      items: items,
      total: (decoded['total'] as num?)?.toInt() ?? 0,
      page: (decoded['page'] as num?)?.toInt() ?? page,
      pageSize: (decoded['page_size'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<ApiArticle> saveArticle({
    required String status,
    required String title,
    required String bodyHtml,
    String? id,
    String? coverImage,
    String? summary,
    String? authorDisplay,
    bool? isOriginal,
  }) async {
    final body = <String, dynamic>{
      'id': id ?? '',
      'title': title,
      'body_html': bodyHtml,
      'status': status,
      'cover_image': coverImage ?? '',
    };
    if (summary != null) body['summary'] = summary;
    if (authorDisplay != null) body['author_display'] = authorDisplay;
    if (isOriginal != null) body['is_original'] = isOriginal;

    final res = await http
        .post(
          Uri.parse(_url('/api/v1/articles')),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (status == 'draft' && res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('保存草稿失败: ${res.statusCode} ${res.body}');
    }
    if (status == 'published' && res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('发布文章失败: ${res.statusCode} ${res.body}');
    }

    final decoded = await _decodeJson(res);
    return ApiArticle.fromJson(decoded);
  }

  /// 我的收藏（需登录）
  Future<ListArticlesResp> listFavorites({int page = 1, int pageSize = 20}) async {
    final uri = Uri.parse(_url('/api/v1/favorites')).replace(queryParameters: {
      'page': '$page',
      'page_size': '$pageSize',
    });
    final res = await http.get(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('拉取收藏失败: ${res.statusCode} ${res.body}');
    }
    final decoded = await _decodeJson(res);
    final itemsJson = (decoded['items'] as List<dynamic>? ?? const []);
    final items = itemsJson.map((e) => ApiArticle.fromJson(e as Map<String, dynamic>)).toList();
    return ListArticlesResp(
      items: items,
      total: (decoded['total'] as num?)?.toInt() ?? 0,
      page: (decoded['page'] as num?)?.toInt() ?? page,
      pageSize: (decoded['page_size'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<bool> getFavoriteStatus(String articleId) async {
    final uri = Uri.parse(_url('/api/v1/favorites/status')).replace(queryParameters: {'article_id': articleId});
    final res = await http.get(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      return false;
    }
    final m = await _decodeJson(res);
    return m['favorited'] == true;
  }

  Future<void> addFavorite(String articleId) async {
    final res = await http
        .post(
          Uri.parse(_url('/api/v1/favorites')),
          headers: await _headers(),
          body: jsonEncode({'article_id': articleId}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(_errBody(res));
    }
  }

  Future<void> removeFavorite(String articleId) async {
    final uri = Uri.parse(_url('/api/v1/favorites')).replace(queryParameters: {'article_id': articleId});
    final res = await http.delete(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(_errBody(res));
    }
  }

  Future<bool> getFollowStatus(String userId) async {
    final uri = Uri.parse(_url('/api/v1/follows/status')).replace(queryParameters: {'user_id': userId});
    final res = await http.get(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      return false;
    }
    final m = await _decodeJson(res);
    return m['following'] == true;
  }

  Future<void> addFollow(String userId) async {
    final res = await http
        .post(
          Uri.parse(_url('/api/v1/follows')),
          headers: await _headers(),
          body: jsonEncode({'user_id': userId}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(_errBody(res));
    }
  }

  Future<void> removeFollow(String userId) async {
    final uri = Uri.parse(_url('/api/v1/follows')).replace(queryParameters: {'user_id': userId});
    final res = await http.delete(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(_errBody(res));
    }
  }

  Future<ApiUserProfile> getUserProfile(String userId) async {
    final uri = Uri.parse(_url('/api/v1/users/profile')).replace(queryParameters: {'user_id': userId});
    final res = await http.get(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(_errBody(res));
    }
    final m = await _decodeJson(res);
    return ApiUserProfile.fromJson(m);
  }

  Future<ListFollowUsersResp> listFollowing({int page = 1, int pageSize = 20}) async {
    final uri = Uri.parse(_url('/api/v1/follows')).replace(queryParameters: {
      'page': '$page',
      'page_size': '$pageSize',
    });
    final res = await http.get(uri, headers: await _headers(json: false)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception(_errBody(res));
    }
    final decoded = await _decodeJson(res);
    final itemsJson = (decoded['items'] as List<dynamic>? ?? const []);
    final items = itemsJson.map((e) => ApiFollowUser.fromJson(e as Map<String, dynamic>)).toList();
    return ListFollowUsersResp(
      items: items,
      total: (decoded['total'] as num?)?.toInt() ?? 0,
      page: (decoded['page'] as num?)?.toInt() ?? page,
      pageSize: (decoded['page_size'] as num?)?.toInt() ?? pageSize,
    );
  }

  /// 上传图片到服务端（POST /api/v1/upload，multipart 字段名 `file`），返回公开 URL。
  Future<String> uploadImageBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final uploadUri = _url('/api/v1/upload');
    final uri = Uri.parse(uploadUri);
    final request = http.MultipartRequest('POST', uri);
    final t = _session.token;
    if (t != null && t.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $t';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception(_errBody(res, requestUrl: uploadUri));
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final url = m['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('上传响应缺少 url');
    }
    return url;
  }

  /// 从本地路径上传（相册/相机返回的 path），内部用 [XFile] 读字节，便于跨平台。
  Future<String> uploadImageFromPath(String path) async {
    final x = XFile(path);
    final bytes = await x.readAsBytes();
    final name = x.name.isNotEmpty ? x.name : p.basename(path);
    return uploadImageBytes(bytes: bytes, filename: name);
  }
}

class ListArticlesResp {
  final List<ApiArticle> items;
  final int total;
  final int page;
  final int pageSize;

  const ListArticlesResp({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

class ApiUserProfile {
  final String id;
  final String username;
  final int followers;
  final int following;
  final bool isFollowing;
  final bool isMe;

  const ApiUserProfile({
    required this.id,
    required this.username,
    required this.followers,
    required this.following,
    required this.isFollowing,
    required this.isMe,
  });

  factory ApiUserProfile.fromJson(Map<String, dynamic> json) {
    return ApiUserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      following: (json['following'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] == true,
      isMe: json['is_me'] == true,
    );
  }
}

class ApiFollowUser {
  final String id;
  final String username;
  final DateTime followedAt;
  final int followers;
  final int following;

  const ApiFollowUser({
    required this.id,
    required this.username,
    required this.followedAt,
    required this.followers,
    required this.following,
  });

  factory ApiFollowUser.fromJson(Map<String, dynamic> json) {
    return ApiFollowUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      followedAt: DateTime.tryParse(json['followed_at']?.toString() ?? '') ?? DateTime.now(),
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      following: (json['following'] as num?)?.toInt() ?? 0,
    );
  }
}

class ListFollowUsersResp {
  final List<ApiFollowUser> items;
  final int total;
  final int page;
  final int pageSize;

  const ListFollowUsersResp({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}
