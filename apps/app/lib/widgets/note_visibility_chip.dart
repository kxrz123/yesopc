import 'package:flutter/material.dart';

/// 备忘录「公开 / 仅自己」小标签（与 [ApiNote.visibility] 一致：`public` | `private`）
class NoteVisibilityChip extends StatelessWidget {
  const NoteVisibilityChip({super.key, required this.visibility});

  final String visibility;

  @override
  Widget build(BuildContext context) {
    final isPublic = visibility.toLowerCase() == 'public';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPublic ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPublic ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        isPublic ? '公开' : '仅自己',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPublic ? const Color(0xFF166534) : const Color(0xFF475569),
        ),
      ),
    );
  }
}
