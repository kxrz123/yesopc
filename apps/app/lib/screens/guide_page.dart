import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/article_model.dart';
import '../services/api_client.dart';
import 'article_detail_page.dart';

/// 指南：已发布文章列表（阅读向），支持下拉刷新与上拉加载更多
class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF94A3B8);
  final ApiClient _api = ApiClient();
  final ScrollController _scrollController = ScrollController();

  List<ApiArticle> _articles = [];
  int _total = 0;
  int _page = 1;
  final int _pageSize = 10;

  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasMore => _articles.length < _total;

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _page = 1;
    });
    try {
      final res = await _api.listArticles(status: 'published', page: 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _articles = res.items;
        _total = res.total;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _articles = []);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    try {
      final res = await _api.listArticles(status: 'published', page: nextPage, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _articles.addAll(res.items);
        _total = res.total;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 与首页一致：封面优先；正文中第一张图（兼容双引号/单引号/data-src）
  String? _rawThumbSource(ApiArticle a) {
    if (a.coverImage.trim().isNotEmpty) return a.coverImage.trim();
    return _firstImgSrcFromHtml(a.bodyHtml);
  }

  String? _firstImgSrcFromHtml(String html) {
    if (html.isEmpty) return null;
    final patterns = [
      RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false),
      RegExp(r"<img[^>]+src='([^']+)'", caseSensitive: false),
      RegExp(r'data-src="([^"]+)"', caseSensitive: false),
      RegExp(r"data-src='([^']+)'", caseSensitive: false),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(html);
      final u = m?.group(1)?.trim();
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  /// 相对路径 `/uploads/...` 需拼上 API 基地址，否则 Image.network 无法加载
  String _resolveImageUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('data:')) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) return 'https:$s';
    final base = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (s.startsWith('/')) return '$base$s';
    return '$base/$s';
  }

  Widget _buildThumb(ApiArticle a) {
    const w = 88.0;
    const h = 88.0;
    final raw = _rawThumbSource(a);
    if (raw == null || raw.isEmpty) {
      return _thumbPlaceholder();
    }
    final src = raw.startsWith('data:') || raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : _resolveImageUrl(raw);

    if (src.startsWith('data:')) {
      final commaIdx = src.indexOf(',');
      if (commaIdx < 0) return _thumbPlaceholder();
      try {
        final bytes = base64Decode(src.substring(commaIdx + 1));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: w,
          height: h,
          errorBuilder: (_, _, _) => _thumbPlaceholder(),
        );
      } catch (_) {
        return _thumbPlaceholder();
      }
    }

    return Image.network(
      src,
      fit: BoxFit.cover,
      width: w,
      height: h,
      errorBuilder: (_, _, _) => _thumbPlaceholder(),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Icon(Icons.article_outlined, color: _textMuted),
    );
  }

  String _time(ApiArticle a) {
    final t = a.publishedAt ?? a.createdAt;
    return DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('指南', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: _loading && _articles.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _articles.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text('暂无指南内容', style: TextStyle(color: _textMuted, fontSize: 14)),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _articles.length + (_hasMore || _loadingMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _articles.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _loadingMore
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      }
                      final a = _articles[i];
                      final snippet = _stripHtml(a.bodyHtml);
                      final short = snippet.length > 100 ? '${snippet.substring(0, 100)}…' : snippet;
                      final author = a.author.isEmpty ? '匿名' : a.author;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 88,
                                      height: 88,
                                      child: _buildThumb(a),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.title.isEmpty ? '（无标题）' : a.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: _textPrimary,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (short.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            short,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(author, style: const TextStyle(fontSize: 12, color: _textMuted)),
                                            const SizedBox(width: 8),
                                            Text(_time(a), style: const TextStyle(fontSize: 12, color: _textMuted)),
                                            const Spacer(),
                                            Icon(Icons.visibility_outlined, size: 14, color: _textMuted),
                                            const SizedBox(width: 4),
                                            Text('${a.readCount}', style: const TextStyle(fontSize: 12, color: _textMuted)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: _textMuted, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
