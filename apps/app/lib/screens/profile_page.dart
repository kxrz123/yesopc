import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/session_service.dart';
import 'articles_page.dart';
import 'favorites_page.dart';
import 'following_page.dart';
import 'social_notes_page.dart';

/// 我的：入口聚合（社群、文章管理、关于等）
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  Future<void> _logout(BuildContext context) async {
    try {
      await ApiClient().logout();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListenableBuilder(
              listenable: SessionService.instance,
              builder: (context, _) {
                final s = SessionService.instance;
                final name = s.username;
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFF1E293B),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/logo.jpg',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'Y',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name ?? 'YesOPC',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.isLoggedIn ? '已登录 · 社群与创作已解锁' : '浏览指南、发现动态、记录社群备忘录',
                            style: const TextStyle(fontSize: 13, color: _textMuted, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    if (s.isLoggedIn)
                      TextButton(
                        onPressed: () => _logout(context),
                        child: const Text('退出'),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('常用'),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.forum_outlined,
            title: '社群动态',
            subtitle: '发布与查看备忘录、标签',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SocialNotesPage()),
            ),
          ),
          _tile(
            context,
            icon: Icons.bookmark_outline,
            title: '我的收藏',
            subtitle: '已收藏的已发布文章',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
          ),
          _tile(
            context,
            icon: Icons.people_outline,
            title: '我的关注',
            subtitle: '查看我关注的用户',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FollowingPage()),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('创作与管理'),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.edit_note_rounded,
            title: '文章管理',
            subtitle: '草稿、发布与编辑',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArticlesPage()),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('其他'),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.info_outline_rounded,
            title: '关于 YesOPC',
            subtitle: '版本与说明',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'YesOPC',
              applicationVersion: '1.0.0',
              applicationIcon: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logo.jpg', width: 48, height: 48, fit: BoxFit.cover),
              ),
              children: const [
                SizedBox(height: 8),
                Text(
                  '面向社群的内容与备忘录体验。账号密码登录已接入。',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        t,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: _textPrimary, size: 26),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _textMuted)),
          trailing: const Icon(Icons.chevron_right, color: _textMuted),
          onTap: onTap,
        ),
      ),
    );
  }
}
