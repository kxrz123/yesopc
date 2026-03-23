import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/article_model.dart';
import '../services/api_client.dart';
import 'article_detail_page.dart';
import 'discover_page.dart';
import 'guide_page.dart';
import 'profile_page.dart';
import 'social_notes_page.dart';

/// YesOPC 首页：顶部栏、今日行动指南、最新洞察、社群动态、底部导航
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const Color _blue = Color(0xFF2563EB);
  static const Color _orange = Color(0xFFF97316);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);

  final ApiClient _api = ApiClient();

  bool _homeLoading = true;
  List<ApiArticle> _publishedArticles = [];

  @override
  void initState() {
    super.initState();
    _loadHomeNews();
  }

  /// [showFullLoading] 为 false 时用于下拉刷新（不整页转圈，只显示 RefreshIndicator）
  Future<void> _loadHomeNews({bool showFullLoading = true}) async {
    if (!mounted) return;
    if (showFullLoading) setState(() => _homeLoading = true);
    try {
      final res = await _api.listArticles(status: 'published', page: 1, pageSize: 20);
      if (!mounted) return;
      setState(() => _publishedArticles = res.items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _publishedArticles = []);
      }
    } finally {
      if (mounted && showFullLoading) setState(() => _homeLoading = false);
    }
  }

  String _thumbUrl(ApiArticle a) {
    if (a.coverImage.isNotEmpty) return a.coverImage;
    if (a.bodyHtml.isEmpty) return '';
    final srcRegExp = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);
    final m = srcRegExp.firstMatch(a.bodyHtml);
    return m?.group(1)?.trim() ?? '';
  }

  List<String> _extractAllImages(String html) {
    if (html.isEmpty) return [];
    final reg = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);
    return reg
        .allMatches(html)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Widget _buildSmartImage(String src, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
    if (src.startsWith('data:')) {
      final commaIdx = src.indexOf(',');
      if (commaIdx < 0) return _imagePlaceholder(height: height);
      try {
        final bytes = base64Decode(src.substring(commaIdx + 1));
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _imagePlaceholder(height: height),
        );
      } catch (_) {
        return _imagePlaceholder(height: height);
      }
    }
    return Image.network(
      src,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => _imagePlaceholder(height: height),
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _articleTime(ApiArticle a) {
    final t = a.publishedAt ?? a.createdAt;
    return DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    Widget tabBody;
    if (_currentIndex == 0) {
      // 首页顶部栏固定不随滚动上移：把 _buildAppBar() 放到 Column 顶部，
      // 其余内容交给下面的 Expanded + CustomScrollView。
      tabBody = Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadHomeNews(showFullLoading: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildLatestInsights()),
                  SliverToBoxAdapter(child: _buildCommunityBuzz()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (_currentIndex == 1) {
      tabBody = const DiscoverPage();
    } else if (_currentIndex == 2) {
      tabBody = const GuidePage();
    } else {
      tabBody = const ProfilePage();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: tabBody),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/logo.jpg',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'YesOPC',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Icon(Icons.search, color: _textPrimary, size: 24),
              const SizedBox(width: 20),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_outlined, color: _textPrimary, size: 24),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('yyyy年MM月dd日').format(DateTime.now()),
            style: TextStyle(fontSize: 14, color: _blue),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayGuide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日行动指南',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFE0E7FF),
                        const Color(0xFFC7D2FE),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.laptop_mac, size: 64, color: _blue.withValues(alpha: 0.5)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '如何在2024年开启你的个人公司 (OPC)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '专为独立创业者打造的起步指南，涵盖从注册到获客的全流程实操建议。',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 18, color: _textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '1.2k 人已阅读',
                            style: TextStyle(fontSize: 13, color: _textMuted),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('立即阅读'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestInsights() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '热点推荐',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 2),
                child: Text('查看全部', style: TextStyle(fontSize: 14, color: _blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: _homeLoading
                ? const Center(child: CircularProgressIndicator())
                : (() {
                    final hot = [..._publishedArticles]..sort((a, b) => b.readCount.compareTo(a.readCount));
                    final hotItems = hot.take(3).toList();
                    if (hotItems.isEmpty) {
                      return const Center(
                        child: Text('暂无热点推荐', style: TextStyle(color: Color(0xFF9AA3AF), fontSize: 12)),
                      );
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: hotItems.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final a = hotItems[i];
                        final thumb = _thumbUrl(a);
                        return SizedBox(
                          width: 160,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    height: 110,
                                    width: 160,
                                    child: thumb.isEmpty
                                        ? Container(
                                            color: const Color(0xFFF0F2F5),
                                            child: const Icon(Icons.image_outlined, size: 24, color: Color(0xFF9AA3AF)),
                                          )
                                        : _buildSmartImage(thumb),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${a.author.isEmpty ? '未知作者' : a.author} · 阅读 ${a.readCount}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _articleTime(a),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF9AA3AF)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  })(),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBox(List<Color> colors, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.9)),
      ),
    );
  }

  Widget _buildCommunityBuzz() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (_homeLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_publishedArticles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text('暂无已发布文章', style: TextStyle(color: Color(0xFF9AA3AF), fontSize: 12)),
            )
          else
            ..._publishedArticles.take(5).map((a) => _buildFeedCard(a)),
        ],
      ),
    );
  }

  Widget _buildFeedCard(ApiArticle a) {
    final snippet = _stripHtml(a.bodyHtml);
    final images = _extractAllImages(a.bodyHtml);
    if (a.coverImage.isNotEmpty && !images.contains(a.coverImage)) {
      images.insert(0, a.coverImage);
    }
    final displayImages = images.take(3).toList();
    final maxTextLen = 100;
    final truncated = snippet.length > maxTextLen;
    final displayText = truncated ? snippet.substring(0, maxTextLen) : snippet;
    final authorName = a.author.isEmpty ? '匿名作者' : a.author;

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: const Color(0xFFF0F2F5), width: 0.8)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- 头部: 头像 + 作者名 --
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
            // -- 标题 --
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
            // -- 正文摘要 + 全文 --
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
                      if (truncated)
                        const TextSpan(text: '... '),
                      if (truncated)
                        TextSpan(
                          text: '全文',
                          style: TextStyle(color: _blue, fontSize: 15),
                        ),
                    ],
                  ),
                ),
              ),
            // -- 图片 --
            if (displayImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildImageGrid(displayImages),
              ),
            // -- 底部互动栏 --
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

  Widget _imagePlaceholder({double? height}) {
    return Container(
      height: height,
      color: const Color(0xFFF0F2F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 24, color: Color(0xFFBFC6D0)),
      ),
    );
  }

  Widget _feedAction(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, '首页'),
              _navItem(1, Icons.explore_rounded, '发现'),
              _centerButton(),
              _navItem(2, Icons.menu_book_rounded, '指南'),
              _navItem(3, Icons.person_rounded, '我的'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.black.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 26,
              color: selected ? Colors.black : _textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.black : _textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.black,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SocialNotesPage()),
          ),
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final length = (distance + dashLength > metric.length) ? metric.length - distance : dashLength;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += length + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
