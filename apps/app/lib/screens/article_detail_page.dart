import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/article_model.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';
import 'user_profile_page.dart';

class ArticleDetailPage extends StatelessWidget {
  final ApiArticle article;

  const ArticleDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final authorName = article.author.isEmpty ? '匿名作者' : article.author;
    final publishTime = article.publishedAt ?? article.createdAt;
    final timeStr = _formatTime(publishTime);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // -- 标题 --
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // -- 作者栏 --
                    _buildAuthorRow(context, authorName, timeStr),
                    const SizedBox(height: 20),
                    // -- 正文 --
                    ..._buildHtmlContent(article.bodyHtml),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F5), width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          if (article.status == 'published') _ArticleFavoriteButton(article: article),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 22, color: Color(0xFF1A1A1A)),
            onSelected: (_) {},
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'share', child: Text('分享')),
              const PopupMenuItem(value: 'report', child: Text('举报')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorRow(BuildContext context, String authorName, String timeStr) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: article.authorId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfilePage(
                          userId: article.authorId,
                          fallbackName: authorName,
                        ),
                      ),
                    ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1E293B),
                  child: Text(
                    authorName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (article.authorId.isNotEmpty) _AuthorFollowButton(authorId: article.authorId),
      ],
    );
  }

  /// 将 HTML 内容解析为 Flutter Widget 列表
  List<Widget> _buildHtmlContent(String html) {
    if (html.isEmpty) {
      return [const Text('暂无内容', style: TextStyle(color: Color(0xFF94A3B8)))];
    }

    final widgets = <Widget>[];
    final tagReg = RegExp(r'<(img|p|h[1-6]|blockquote|ul|ol|li|br|hr|a|strong|em|div)[^>]*>|</?(p|h[1-6]|blockquote|ul|ol|li|br|hr|div)>', caseSensitive: false);

    final segments = <_HtmlSegment>[];
    int cursor = 0;

    final imgReg = RegExp(r'<img[^>]+src="([^"]+)"[^>]*/?>', caseSensitive: false);
    final pOpenReg = RegExp(r'<(p|h[1-6]|li|blockquote|div)\b[^>]*>', caseSensitive: false);
    final pCloseReg = RegExp(r'</(p|h[1-6]|li|blockquote|div)>', caseSensitive: false);
    final hrReg = RegExp(r'<hr\s*/?>', caseSensitive: false);

    for (final imgMatch in imgReg.allMatches(html)) {
      final before = html.substring(cursor, imgMatch.start);
      if (before.trim().isNotEmpty) {
        segments.add(_HtmlSegment(type: 'text', content: before));
      }
      segments.add(_HtmlSegment(type: 'img', content: imgMatch.group(1) ?? ''));
      cursor = imgMatch.end;
    }
    if (cursor < html.length) {
      final remaining = html.substring(cursor);
      if (remaining.trim().isNotEmpty) {
        segments.add(_HtmlSegment(type: 'text', content: remaining));
      }
    }

    for (final seg in segments) {
      if (seg.type == 'img') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImage(seg.content),
          ),
        ));
      } else {
        final paragraphs = _splitIntoParagraphs(seg.content);
        for (final p in paragraphs) {
          if (p.tag == 'hr') {
            widgets.add(Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: const Color(0xFFE2E8F0), thickness: 0.8),
            ));
          } else if (p.text.trim().isNotEmpty) {
            widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTextWidget(p),
            ));
          }
        }
      }
    }

    return widgets;
  }

  List<_ParsedParagraph> _splitIntoParagraphs(String html) {
    final results = <_ParsedParagraph>[];
    final blockReg = RegExp(
      r'<(h[1-6]|p|blockquote|li|div)\b[^>]*>(.*?)</\1>|<hr\s*/?>',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = blockReg.allMatches(html);
    if (matches.isEmpty) {
      final text = _stripTags(html).trim();
      if (text.isNotEmpty) {
        results.add(_ParsedParagraph(tag: 'p', text: text));
      }
      return results;
    }

    for (final m in matches) {
      if (m.group(0)?.startsWith('<hr') == true) {
        results.add(_ParsedParagraph(tag: 'hr', text: ''));
        continue;
      }
      final tag = m.group(1)?.toLowerCase() ?? 'p';
      final inner = m.group(2) ?? '';
      final text = _stripTags(inner).trim();
      if (text.isNotEmpty) {
        results.add(_ParsedParagraph(tag: tag, text: text));
      }
    }

    if (results.isEmpty) {
      final text = _stripTags(html).trim();
      if (text.isNotEmpty) {
        results.add(_ParsedParagraph(tag: 'p', text: text));
      }
    }

    return results;
  }

  Widget _buildTextWidget(_ParsedParagraph p) {
    double fontSize;
    FontWeight fontWeight;

    switch (p.tag) {
      case 'h1':
        fontSize = 22;
        fontWeight = FontWeight.w800;
        break;
      case 'h2':
        fontSize = 20;
        fontWeight = FontWeight.w700;
        break;
      case 'h3':
        fontSize = 18;
        fontWeight = FontWeight.w700;
        break;
      case 'h4':
      case 'h5':
      case 'h6':
        fontSize = 16;
        fontWeight = FontWeight.w600;
        break;
      case 'blockquote':
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: const Color(0xFFCBD5E1), width: 3)),
            color: const Color(0xFFF8FAFC),
          ),
          child: Text(
            p.text,
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF64748B),
              height: 1.7,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case 'li':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, right: 8),
              child: Icon(Icons.circle, size: 5, color: Color(0xFF64748B)),
            ),
            Expanded(
              child: Text(
                p.text,
                style: const TextStyle(fontSize: 16, color: Color(0xFF374151), height: 1.7),
              ),
            ),
          ],
        );
      default:
        fontSize = 16;
        fontWeight = FontWeight.normal;
    }

    return Text(
      p.text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: const Color(0xFF374151),
        height: 1.7,
      ),
    );
  }

  Widget _buildImage(String src) {
    if (src.startsWith('data:')) {
      final commaIdx = src.indexOf(',');
      if (commaIdx < 0) return _imgPlaceholder();
      try {
        final bytes = base64Decode(src.substring(commaIdx + 1));
        return Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _imgPlaceholder(),
        );
      } catch (_) {
        return _imgPlaceholder();
      }
    }
    return Image.network(
      src,
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      height: 160,
      color: const Color(0xFFF0F2F5),
      child: const Center(child: Icon(Icons.image_outlined, size: 32, color: Color(0xFFBFC6D0))),
    );
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFF0F2F5), width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, -1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.centerLeft,
              child: const Text('我来说两句...', style: TextStyle(fontSize: 14, color: Color(0xFFADB5BD))),
            ),
          ),
          const SizedBox(width: 12),
          _bottomAction(Icons.thumb_up_alt_outlined, '${article.readCount}'),
          const SizedBox(width: 16),
          _bottomAction(Icons.chat_bubble_outline, '0'),
          const SizedBox(width: 16),
          _bottomAction(Icons.share_outlined, '0'),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 3),
        Text(count, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }
}

/// 文章收藏（仅已发布文显示）
class _ArticleFavoriteButton extends StatefulWidget {
  final ApiArticle article;

  const _ArticleFavoriteButton({required this.article});

  @override
  State<_ArticleFavoriteButton> createState() => _ArticleFavoriteButtonState();
}

class _ArticleFavoriteButtonState extends State<_ArticleFavoriteButton> {
  final ApiClient _api = ApiClient();
  bool? _favorited;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!SessionService.instance.isLoggedIn) {
      if (mounted) setState(() => _favorited = false);
      return;
    }
    try {
      final v = await _api.getFavoriteStatus(widget.article.id);
      if (mounted) setState(() => _favorited = v);
    } catch (_) {
      if (mounted) setState(() => _favorited = false);
    }
  }

  Future<void> _toggle() async {
    if (!SessionService.instance.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再收藏')),
      );
      return;
    }
    if (_busy || _favorited == null) return;
    final was = _favorited!;
    setState(() => _busy = true);
    try {
      if (was) {
        await _api.removeFavorite(widget.article.id);
      } else {
        await _api.addFavorite(widget.article.id);
      }
      if (!mounted) return;
      setState(() {
        _favorited = !was;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(!was ? '已加入收藏' : '已取消收藏')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fav = _favorited;
    return IconButton(
      tooltip: '收藏',
      icon: fav == true
          ? const Icon(Icons.bookmark, size: 22, color: Color(0xFF1A1A1A))
          : const Icon(Icons.bookmark_border, size: 22, color: Color(0xFF1A1A1A)),
      onPressed: (_busy || fav == null) ? null : _toggle,
    );
  }
}

class _AuthorFollowButton extends StatefulWidget {
  final String authorId;
  const _AuthorFollowButton({required this.authorId});

  @override
  State<_AuthorFollowButton> createState() => _AuthorFollowButtonState();
}

class _AuthorFollowButtonState extends State<_AuthorFollowButton> {
  final ApiClient _api = ApiClient();
  ApiUserProfile? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _api.getUserProfile(widget.authorId);
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      if (mounted) setState(() => _profile = null);
    }
  }

  Future<void> _toggle() async {
    final p = _profile;
    if (p == null || p.isMe || _busy) return;
    if (!SessionService.instance.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录后再关注')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (p.isFollowing) {
        await _api.removeFollow(widget.authorId);
      } else {
        await _api.addFollow(widget.authorId);
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
    if (p == null) return const SizedBox.shrink();
    final isMe = p.isMe;
    return OutlinedButton(
      onPressed: (isMe || _busy) ? null : _toggle,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF111827),
        side: const BorderSide(color: Color(0xFF111827)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        isMe ? '自己' : (p.isFollowing ? '已关注' : '+ 关注'),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HtmlSegment {
  final String type;
  final String content;
  _HtmlSegment({required this.type, required this.content});
}

class _ParsedParagraph {
  final String tag;
  final String text;
  _ParsedParagraph({required this.tag, required this.text});
}
