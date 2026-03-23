import 'package:flutter/material.dart';

import '../models/article_model.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';
import 'article_detail_page.dart';

/// 我的收藏（已发布文章）
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final ApiClient _api = ApiClient();
  final List<ApiArticle> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!SessionService.instance.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final res = await _api.listFavorites(page: 1, pageSize: 100);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E293B);
    const muted = Color(0xFF64748B);

    if (!SessionService.instance.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的收藏', style: TextStyle(fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('请先登录后查看收藏', textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('我的收藏', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('暂无收藏', style: TextStyle(color: muted))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final a = _items[i];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          title: Text(
                            a.title.isEmpty ? '无标题' : a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: primary),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              a.author.isEmpty ? '匿名' : a.author,
                              style: const TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: muted),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
