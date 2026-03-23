import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/article_model.dart';
import '../models/note_model.dart';
import '../services/api_client.dart';
import '../widgets/note_content_with_hashtags.dart';
import '../widgets/note_visibility_chip.dart';
import 'article_detail_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.userId,
    this.fallbackName,
  });

  final String userId;
  final String? fallbackName;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final ApiClient _api = ApiClient();
  ApiUserProfile? _profile;
  bool _loading = true;
  bool _busy = false;
  List<ApiArticle> _articles = const [];
  List<ApiNote> _notes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _api.getUserProfile(widget.userId);
      final list = await _api.listArticles(status: 'published', page: 1, pageSize: 20, authorId: widget.userId);
      final notes = await _api.listNotes(authorId: widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _articles = list.items;
        _notes = notes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleFollow() async {
    final p = _profile;
    if (p == null || p.isMe || _busy) return;
    setState(() => _busy = true);
    try {
      if (p.isFollowing) {
        await _api.removeFollow(p.id);
      } else {
        await _api.addFollow(p.id);
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final displayName = p?.username.isNotEmpty == true
        ? p!.username
        : (widget.fallbackName?.isNotEmpty == true ? widget.fallbackName! : '用户');
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人主页'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF1E293B),
                          child: Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                '关注 ${p?.following ?? 0} · 粉丝 ${p?.followers ?? 0}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        if (p != null && !p.isMe)
                          OutlinedButton(
                            onPressed: _busy ? null : _toggleFollow,
                            child: Text(p.isFollowing ? '已关注' : '+ 关注'),
                          ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(text: 'TA发布的文章'),
                        Tab(text: 'TA公开备忘录'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: TabBarView(
                        children: [
                          _buildArticlesTab(),
                          _buildNotesTab(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildArticlesTab() {
    if (_articles.isEmpty) {
      return const Center(
        child: Text('暂无已发布文章', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: _articles.length,
      itemBuilder: (_, i) {
        final a = _articles[i];
        return _buildHomeStyleArticleCard(a);
      },
    );
  }

  Widget _buildHomeStyleArticleCard(ApiArticle a) {
    final snippet = _stripHtml(a.bodyHtml);
    final images = _extractAllImages(a.bodyHtml);
    if (a.coverImage.isNotEmpty && !images.contains(a.coverImage)) {
      images.insert(0, a.coverImage);
    }
    final displayImages = images.take(3).toList();
    final maxTextLen = 100;
    final truncated = snippet.length > maxTextLen;
    final displayText = truncated ? snippet.substring(0, maxTextLen) : snippet;
    final authorName = a.author.isEmpty ? (_profile?.username ?? '匿名作者') : a.author;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a)),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F2F5), width: 0.8)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF1E293B),
                  child: Text(
                    authorName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _articleTime(a),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, size: 20, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 10),
            if (a.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  a.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (displayText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RichText(
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.5),
                    children: [
                      TextSpan(text: displayText),
                      if (truncated) const TextSpan(text: '... '),
                      if (truncated) const TextSpan(text: '全文', style: TextStyle(color: Color(0xFF2563EB), fontSize: 15)),
                    ],
                  ),
                ),
              ),
            if (displayImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildImageGrid(displayImages),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _feedAction(Icons.share_outlined, '分享'),
                  const SizedBox(width: 32),
                  _feedAction(Icons.chat_bubble_outline, '评论'),
                  const SizedBox(width: 32),
                  _feedAction(Icons.thumb_up_alt_outlined, '${a.readCount}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: _buildSmartImage(images[0], width: double.infinity),
        ),
      );
    }
    return Row(
      children: images
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: e.key == 0 ? 0 : 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _buildSmartImage(e.value),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSmartImage(String src, {double? width}) {
    return Image.network(
      src,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(child: Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _feedAction(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _extractAllImages(String html) {
    if (html.isEmpty) return [];
    final reg = RegExp('<img[^>]+src=(?:"([^"]+)"|\\\'([^\\\']+)\\\'|([^ >]+))', caseSensitive: false);
    final out = <String>[];
    for (final m in reg.allMatches(html)) {
      final src = m.group(1) ?? m.group(2) ?? m.group(3);
      if (src != null && src.trim().isNotEmpty) out.add(src.trim());
    }
    return out;
  }

  String _articleTime(ApiArticle a) {
    final dt = (a.publishedAt ?? a.createdAt).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  Widget _buildNotesTab() {
    if (_notes.isEmpty) {
      return const Center(
        child: Text('暂无公开备忘录', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final n = _notes[i];
        return _buildDiscoverStyleNoteCard(n);
      },
    );
  }

  Widget _buildDiscoverStyleNoteCard(ApiNote n) {
    final author = n.author.isNotEmpty ? n.author : (_profile?.username ?? '匿名用户');
    const contentBaseStyle = TextStyle(fontSize: 15, color: Color(0xFF1E293B), height: 1.55);
    const contentLinkStyle = TextStyle(
      fontSize: 15,
      color: Color(0xFF2563EB),
      height: 1.55,
      fontWeight: FontWeight.w600,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1E293B),
                    child: Text(
                      author.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _noteTimeText(n.createdAt),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  NoteVisibilityChip(visibility: n.visibility),
                ],
              ),
              const SizedBox(height: 12),
              NoteContentWithHashtags(
                content: n.contentText,
                tags: const [],
                maxLines: null,
                baseStyle: contentBaseStyle,
                linkStyle: contentLinkStyle,
                onTagTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _noteTimeText(DateTime t) {
    return DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
  }
}

