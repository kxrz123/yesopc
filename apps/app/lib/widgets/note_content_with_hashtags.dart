import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/tag_model.dart';

/// 备忘录正文：`#标签` 蓝字；点击与 [tags] 中名称匹配的片段触发 [onTagTap]
class NoteContentWithHashtags extends StatefulWidget {
  const NoteContentWithHashtags({
    super.key,
    required this.content,
    required this.tags,
    required this.onTagTap,
    /// 为 null 时不限制行数（发现页全文）；非 null 时超出省略
    this.maxLines,
    this.baseStyle,
    this.linkStyle,
  });

  final String content;
  final List<ApiTag> tags;
  final void Function(ApiTag tag) onTagTap;

  final int? maxLines;

  final TextStyle? baseStyle;
  final TextStyle? linkStyle;

  @override
  State<NoteContentWithHashtags> createState() => _NoteContentWithHashtagsState();
}

class _NoteContentWithHashtagsState extends State<NoteContentWithHashtags> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final RegExp _hashRe = RegExp(r'[#＃]\s*[^\s\n]+');

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  ApiTag? _lookupTag(String raw) {
    final name = raw.replaceFirst(RegExp(r'^[#＃]\s*'), '').trim();
    if (name.isEmpty) return null;
    final lower = name.toLowerCase();
    for (final t in widget.tags) {
      if (t.name.trim().toLowerCase() == lower) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final base = widget.baseStyle ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B));
    final link = widget.linkStyle ?? base.copyWith(color: const Color(0xFF2563EB), fontWeight: FontWeight.w600);

    final spans = <TextSpan>[];
    final text = widget.content;
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    var start = 0;
    for (final m in _hashRe.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start), style: base));
      }
      final raw = m.group(0)!;
      final tag = _lookupTag(raw);
      if (tag != null) {
        final rec = TapGestureRecognizer()..onTap = () => widget.onTagTap(tag);
        _recognizers.add(rec);
        spans.add(TextSpan(text: raw, style: link, recognizer: rec));
      } else {
        spans.add(TextSpan(text: raw, style: link));
      }
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }

    final max = widget.maxLines;
    return Text.rich(
      TextSpan(children: spans),
      maxLines: max,
      overflow: max == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}
