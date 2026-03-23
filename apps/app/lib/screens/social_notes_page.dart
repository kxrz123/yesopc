import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/note_model.dart';
import '../models/tag_model.dart';
import '../services/api_client.dart';
import '../widgets/note_content_with_hashtags.dart';
import '../widgets/note_visibility_chip.dart';

class SocialNotesPage extends StatefulWidget {
  const SocialNotesPage({super.key});

  @override
  State<SocialNotesPage> createState() => _SocialNotesPageState();
}

class _SocialNotesPageState extends State<SocialNotesPage> {
  final ApiClient api = ApiClient();

  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  /// # 标签联想（仅点击列表选用）
  List<ApiTag> _tagSuggestions = [];

  List<ApiNote> _notes = [];
  List<ApiTag> _tags = [];

  bool _loading = false;
  String? _selectedDateKey; // YYYY-MM-DD
  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();

  /// 当前选中的标签（用于筛选列表与日历计数）
  ApiTag? _selectedTag;

  /// 发布可见范围：`public` 出现在发现频道；`private` 仅自己可见
  String _publishVisibility = 'public';

  /// 点击联想列表会先让输入框失焦；若立刻清空列表，InkWell 的 onTap 无法触发。
  /// 延迟清空，给列表项点击留出时间；选用后由 _applyTagSuggestion 同步清空。
  void _onFocusNodeChanged() {
    if (_contentFocusNode.hasFocus) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (_contentFocusNode.hasFocus) return;
      if (_tagSuggestions.isEmpty) return;
      setState(() {
        _tagSuggestions = [];
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
    _contentFocusNode.addListener(_onFocusNodeChanged);
    _refresh();
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentFocusNode.removeListener(_onFocusNodeChanged);
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  int _lastHashIndex(String before) {
    final a = before.lastIndexOf('#');
    final b = before.lastIndexOf('＃');
    return a > b ? a : b;
  }

  /// 光标若在 `#xxx` 片段内，返回 xxx（可为空表示刚输入 #）；否则 null
  String? _parseHashtagQuery() {
    final c = _contentController;
    final sel = c.selection;
    if (!sel.isValid || sel.start != sel.end) return null;
    final before = c.text.substring(0, sel.start);
    final hashIdx = _lastHashIndex(before);
    if (hashIdx < 0) return null;
    final fragment = before.substring(hashIdx);
    if (fragment.isEmpty) return null;
    final head = fragment[0];
    if (head != '#' && head != '＃') return null;
    if (fragment.contains(' ') || fragment.contains('\n')) return null;
    return fragment.substring(1);
  }

  void _onContentChanged() {
    // 失焦时不要立刻清空联想，否则点击下拉项时列表先消失，onTap 无法选用
    if (!_contentFocusNode.hasFocus) return;
    final q = _parseHashtagQuery();
    if (q == null) {
      if (_tagSuggestions.isNotEmpty) {
        setState(() {
          _tagSuggestions = [];
        });
      }
      return;
    }
    final qLower = q.toLowerCase();
    final filtered = q.isEmpty
        ? _tags.take(8).toList()
        : _tags.where((t) => t.name.toLowerCase().startsWith(qLower)).take(8).toList();
    setState(() {
      _tagSuggestions = filtered;
    });
  }

  void _applyTagSuggestion(ApiTag tag) {
    final c = _contentController;
    final text = c.text;
    final end = c.selection.start;
    if (end < 0 || end > text.length) return;
    final beforeEnd = text.substring(0, end);
    final hashIdx = _lastHashIndex(beforeEnd);
    if (hashIdx < 0) return;
    final tail = text.substring(end);
    final newText = '${text.substring(0, hashIdx)}#${tag.name} $tail';
    final newPos = hashIdx + 1 + tag.name.length + 1;
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newPos),
    );
    setState(() {
      _tagSuggestions = [];
    });
    // 点击列表选用后收回焦点，便于继续输入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocusNode.requestFocus();
    });
  }

  String _formatDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toLocal());

  /// 按当前选中标签过滤后的笔记（未选标签则为全部）
  List<ApiNote> _tagFilteredNotes() {
    if (_selectedTag == null) return _notes;
    return _notes.where((n) => _noteMatchesTag(n, _selectedTag!)).toList();
  }

  /// 正文是否包含该标签对应的 hashtag（与后端解析规则接近）
  bool _noteMatchesTag(ApiNote n, ApiTag tag) {
    final name = tag.name.trim();
    if (name.isEmpty) return false;
    return RegExp(r'[#＃]\s*' + RegExp.escape(name)).hasMatch(n.contentText);
  }

  Map<String, List<ApiNote>> _notesByDate() {
    final out = <String, List<ApiNote>>{};
    for (final n in _tagFilteredNotes()) {
      final key = _formatDay(n.createdAt);
      out.putIfAbsent(key, () => []).add(n);
    }
    return out;
  }

  Map<String, int> _countsByDate() {
    final byDate = _notesByDate();
    return byDate.map((k, v) => MapEntry(k, v.length));
  }

  List<ApiNote> _filteredNotes() {
    final list = _tagFilteredNotes();
    if (_selectedDateKey == null) return list;
    final byDate = <String, List<ApiNote>>{};
    for (final n in list) {
      final k = _formatDay(n.createdAt);
      byDate.putIfAbsent(k, () => []).add(n);
    }
    return byDate[_selectedDateKey!] ?? const [];
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([api.listNotes(mine: true), api.listTags()]);
      _notes = results[0] as List<ApiNote>;
      _tags = results[1] as List<ApiTag>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSaveNote() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入备忘录内容')));
      return;
    }

    try {
      await api.createNote(contentText: text, visibility: _publishVisibility);
      _contentController.clear();
      await _refresh();
      if (mounted) setState(() => _selectedDateKey = _formatDay(DateTime.now()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildSelectedDatePill() {
    if (_selectedDateKey == null) return const SizedBox.shrink();
    final memoCount = _countsByDate()[_selectedDateKey!] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDateKey!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '$memoCount 条',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => setState(() => _selectedDateKey = null),
            icon: const Text('×', style: TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
            tooltip: '取消日期筛选',
          ),
        ],
      ),
    );
  }

  /// 点击列表下方空白 / 加载占位：收起键盘并清除标签筛选
  void _onTapBlank() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedTag != null) {
      setState(() => _selectedTag = null);
    }
  }

  /// 点击备忘录卡片：只收起键盘，不取消标签筛选
  void _onDismissKeyboardOnly() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 紧凑版「公开 / 仅自己」（替代占满整行的 SegmentedButton）
  Widget _buildPublishVisibilityPills() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '会出现在「发现」频道',
          child: _buildVisibilityTogglePill(
            label: '公开',
            selected: _publishVisibility == 'public',
            onTap: () => setState(() => _publishVisibility = 'public'),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '仅在本页可见，不出现在发现',
          child: _buildVisibilityTogglePill(
            label: '仅自己',
            selected: _publishVisibility == 'private',
            onTap: () => setState(() => _publishVisibility = 'private'),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityTogglePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE0E7FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countsByDate = _countsByDate();
    final filtered = _filteredNotes();

    // 必须用 Scaffold（内含 Material），否则从底部「+」 push 进来时 TextField 会报 No Material widget found
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('社群动态', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      // 外层 GestureDetector 包 ListView 时，滚动子组件会抢走手势，空白处 onTap 常不触发。
      // 用 CustomScrollView + 末尾 SliverFillRemaining 接住列表下方的空白区域点击。
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverToBoxAdapter(child: _buildComposerCard(countsByDate)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: GestureDetector(
                onTap: _onTapBlank,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            )
          else
            ...[
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('备忘录列表', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...filtered.map((n) => _buildNoteItem(n)),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('暂无数据', style: TextStyle(color: Color(0xFF9AA3AF), fontSize: 12)),
                      ),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: GestureDetector(
                  onTap: _onTapBlank,
                  behavior: HitTestBehavior.opaque,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposerCard(Map<String, int> countsByDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text('发布备忘录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: _showCalendar ? '收起日历' : '打开日历',
                    icon: Icon(
                      Icons.calendar_month_outlined,
                      color: _showCalendar ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _showCalendar = !_showCalendar),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    minLines: 4,
                    maxLines: 6,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '输入 # 可联想已有标签，点击列表选用',
                    ),
                  ),
                  if (_tagSuggestions.isNotEmpty) _buildTagSuggestList(),
                ],
              ),
              _buildSelectedDatePill(),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('可见范围', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  _buildPublishVisibilityPills(),
                  const SizedBox(height: 4),
                  Text(
                    _publishVisibility == 'public' ? '将出现在「发现」频道' : '不会出现在「发现」，仅在此列表可见',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onSaveNote,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('保存'),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _showCalendar
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _buildTableCalendar(countsByDate),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// # 输入联想列表（点击选用）
  Widget _buildTagSuggestList() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _tagSuggestions.length,
            itemBuilder: (context, i) {
              final t = _tagSuggestions[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _applyTagSuggestion(t);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Text('#', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTableCalendar(Map<String, int> countsByDate) {
    return TableCalendar(
      locale: 'zh_CN',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      startingDayOfWeek: StartingDayOfWeek.monday,
      // 仅月视图，隐藏「2 weeks / week」切换（table_calendar 默认可切换视图高度）
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: '月'},
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) {
        if (_selectedDateKey == null) return false;
        return _formatDay(day) == _selectedDateKey;
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDateKey = _formatDay(selectedDay);
          _focusedDay = focusedDay;
          _showCalendar = false; // 选中日期后收起日历
        });
      },
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: const Color(0xFFE0E7FF),
          borderRadius: BorderRadius.circular(8),
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        defaultDecoration: const BoxDecoration(),
        weekendTextStyle: const TextStyle(color: Colors.black54),
        outsideTextStyle: const TextStyle(color: Colors.black38),
      ),
      calendarBuilders: CalendarBuilders(
        // 星期行不显示「周一」等，只显示「一」…「日」
        dowBuilder: (context, day) {
          const labels = ['一', '二', '三', '四', '五', '六', '日'];
          return Center(
            child: Text(
              labels[day.weekday - 1],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          );
        },
        defaultBuilder: (context, day, focusedDay) {
          final key = _formatDay(day);
          final count = countsByDate[key] ?? 0;
          final isSelected = _selectedDateKey == key;
          final bg = isSelected
              ? Colors.black
              : count > 0
                  ? const Color(0xFFE0E7FF)
                  : Colors.transparent;
          final fg = isSelected
              ? Colors.white
              : count > 0
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B);

          return Tooltip(
            message: count > 0 ? '$key 有 $count 条备忘录' : '无备忘录',
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.black
                      : count > 0
                          ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                          : Colors.transparent,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoteItem(ApiNote n) {
    final dayKey = _formatDay(n.createdAt);
    // 消费点击：收起键盘，但不取消标签筛选（与空白处 _onTapBlank 区分）
    return GestureDetector(
      onTap: _onDismissKeyboardOnly,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(dayKey, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
                NoteVisibilityChip(visibility: n.visibility),
              ],
            ),
            const SizedBox(height: 6),
            NoteContentWithHashtags(
              content: n.contentText,
              tags: _tags,
              maxLines: 4,
              onTagTap: (tag) => setState(() => _selectedTag = tag),
            ),
          ],
        ),
      ),
    );
  }
}
