import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/article_model.dart';
import '../services/api_client.dart';
import '../widgets/article_rich_editor_page.dart';
import 'article_detail_page.dart';

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  static const Color _btnBlack = Color(0xFF000000);

  final ApiClient api = ApiClient();

  bool _loadingDraft = false;
  bool _loadingPublished = false;

  List<ApiArticle> _drafts = [];
  List<ApiArticle> _published = [];

  int _draftPage = 1;
  int _publishedPage = 1;
  final int _pageSize = 5;
  int _draftTotal = 0;
  int _publishedTotal = 0;

  bool _showDraft = true;

  @override
  void initState() {
    super.initState();
    _refreshDraft();
    _refreshPublished();
  }

  String stripHtml(String html) {
    final stripped = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.length <= 90) return stripped;
    return stripped.substring(0, 90);
  }

  String? extractFirstImageSrc(String html) {
    if (html.isEmpty) return null;
    // 简化处理：优先匹配双引号形式的 src/data-src
    // （后台 Quill 输出的 HTML 通常是这种格式）
    final srcRegExp = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);
    final dataSrcRegExp = RegExp(r'<img[^>]+data-src="([^"]+)"', caseSensitive: false);
    final m = srcRegExp.firstMatch(html) ?? dataSrcRegExp.firstMatch(html);
    final src = m?.group(1);
    if (src == null) return null;
    final cleaned = src.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _refreshDraft() async {
    setState(() => _loadingDraft = true);
    try {
      final res = await api.listArticles(status: 'draft', page: _draftPage, pageSize: _pageSize);
      _drafts = res.items;
      _draftTotal = res.total;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  Future<void> _refreshPublished() async {
    setState(() => _loadingPublished = true);
    try {
      final res = await api.listArticles(status: 'published', page: _publishedPage, pageSize: _pageSize);
      _published = res.items;
      _publishedTotal = res.total;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingPublished = false);
    }
  }

  void _openEditor({required bool isEdit, ApiArticle? article}) {
    final String? id = isEdit ? article?.id : null;

    Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (ctx) => ArticleRichEditorPage(
          api: api,
          initialTitle: isEdit ? article?.title ?? '' : '',
          initialHtml: isEdit ? article?.bodyHtml ?? '' : '',
          isEdit: isEdit,
          uploadImage: api.uploadImageFromPath,
          onSaveDraft: (title, bodyHtml) async {
            await api.saveArticle(
              id: id,
              status: 'draft',
              title: title,
              bodyHtml: bodyHtml,
              coverImage: article?.coverImage,
            );
            if (ctx.mounted) Navigator.of(ctx).pop();
            await Future.wait([_refreshDraft(), _refreshPublished()]);
          },
          onUpsertDraft: (title, bodyHtml) => api.saveArticle(
            id: id,
            status: 'draft',
            title: title,
            bodyHtml: bodyHtml,
            coverImage: article?.coverImage,
          ),
        ),
      ),
    ).then((_) async {
      await Future.wait([_refreshDraft(), _refreshPublished()]);
    });
  }

  Widget _buildPagination({
    required int current,
    required int total,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    final maxPage = (total / _pageSize).ceil().clamp(1, 9999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: current <= 1 ? null : onPrev,
            icon: const Icon(Icons.chevron_left),
            color: _btnBlack,
          ),
          Text('第 $current / $maxPage 页', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          IconButton(
            onPressed: current >= maxPage ? null : onNext,
            icon: const Icon(Icons.chevron_right),
            color: _btnBlack,
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(ApiArticle a) {
    final thumb = a.coverImage.isNotEmpty ? a.coverImage : extractFirstImageSrc(a.bodyHtml);
    final snippet = stripHtml(a.bodyHtml);

    return InkWell(
      onTap: () {
        if (_showDraft) {
          _openEditor(isEdit: true, article: a);
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a)));
        }
      },
      // 已发布：长按进入编辑；草稿箱点击已是编辑，无需长按
      onLongPress: _showDraft ? null : () => _openEditor(isEdit: true, article: a),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 92,
                    color: const Color(0xFFF0F2F5),
                    child: thumb == null
                        ? const Icon(Icons.image_outlined, size: 20, color: Color(0xFF9AA3AF))
                        : Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return const Icon(Icons.broken_image_outlined, size: 18, color: Color(0xFF9AA3AF));
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt.toLocal()),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _showDraft ? _drafts : _published;
    final loading = _showDraft ? _loadingDraft : _loadingPublished;
    final total = _showDraft ? _draftTotal : _publishedTotal;
    final page = _showDraft ? _draftPage : _publishedPage;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
        Row(
          children: [
            const Expanded(child: Text('文章', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            IconButton(
              onPressed: () => _openEditor(isEdit: false),
              icon: const Icon(Icons.add),
              color: _btnBlack,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showDraft = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _showDraft ? _btnBlack : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Text(
                        '草稿箱（$_draftTotal）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _showDraft ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showDraft = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: !_showDraft ? _btnBlack : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Text(
                        '已发布（$_publishedTotal）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: !_showDraft ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('暂无文章', style: TextStyle(color: Color(0xFF9AA3AF), fontSize: 12)),
          )
        else
          ...list.map(_buildArticleCard),
        _buildPagination(
          current: page,
          total: total,
          onPrev: _showDraft
              ? () async {
                  setState(() => _draftPage -= 1);
                  await _refreshDraft();
                }
              : () async {
                  setState(() => _publishedPage -= 1);
                  await _refreshPublished();
                },
          onNext: _showDraft
              ? () async {
                  setState(() => _draftPage += 1);
                  await _refreshDraft();
                }
              : () async {
                  setState(() => _publishedPage += 1);
                  await _refreshPublished();
                },
        ),
          ],
        ),
      ),
    );
  }
}

