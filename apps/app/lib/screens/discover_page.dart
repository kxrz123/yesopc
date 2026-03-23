import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note_model.dart';
import '../models/tag_model.dart';
import '../services/api_client.dart';
import '../widgets/note_content_with_hashtags.dart';
import '../widgets/note_visibility_chip.dart';

/// 发现：展示所有用户发布的公开动态（notes）
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF94A3B8);

  final ApiClient _api = ApiClient();

  List<ApiNote> _notes = [];
  List<ApiTag> _tags = [];
  ApiTag? _selectedTag;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        // 明确不要 mine=1；仅展示公开动态
        _api.listNotes(mine: false),
        _api.listTags(),
      ]);
      if (!mounted) return;
      final raw = results[0] as List<ApiNote>;
      setState(() {
        // 双保险：仅展示公开（防旧网关/缓存混入 private）
        _notes = raw.where((n) => n.visibility.toLowerCase() == 'public').toList();
        _tags = results[1] as List<ApiTag>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() {
          _notes = [];
          _tags = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _noteMatchesTag(ApiNote n, ApiTag tag) {
    final name = tag.name.trim();
    if (name.isEmpty) return false;
    return RegExp(r'[#＃]\s*' + RegExp.escape(name)).hasMatch(n.contentText);
  }

  List<ApiNote> _filteredNotes() {
    final public = _notes.where((n) => n.visibility.toLowerCase() == 'public').toList();
    if (_selectedTag == null) return public;
    return public.where((n) => _noteMatchesTag(n, _selectedTag!)).toList();
  }

  String _timeText(DateTime t) {
    return DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('发现', style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_selectedTag != null) {
            setState(() => _selectedTag = null);
          }
        },
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading && _notes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            _selectedTag != null ? '暂无该标签下的公开动态' : '暂无公开动态',
                            style: const TextStyle(color: _textMuted, fontSize: 14),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _buildCard(filtered[i]),
                    ),
        ),
      ),
    );
  }

  Widget _buildCard(ApiNote n) {
    final author = n.author.isNotEmpty ? n.author : '匿名用户';
    const contentBaseStyle = TextStyle(fontSize: 15, color: _textPrimary, height: 1.55);
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
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeText(n.createdAt),
                          style: const TextStyle(fontSize: 12, color: _textMuted),
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
                tags: _tags,
                maxLines: null,
                baseStyle: contentBaseStyle,
                linkStyle: contentLinkStyle,
                onTagTap: (tag) => setState(() => _selectedTag = tag),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
