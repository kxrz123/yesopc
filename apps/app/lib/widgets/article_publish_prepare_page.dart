import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/article_model.dart';
import '../screens/article_detail_page.dart';
import '../services/api_client.dart';

/// 公众号式「发表前」页：封面、摘要、原创、作者、底部存草稿 / 预览 / 发表
class ArticlePublishPreparePage extends StatefulWidget {
  const ArticlePublishPreparePage({
    super.key,
    required this.api,
    required this.article,
    required this.bodyHtml,
    this.uploadImage,
  });

  final ApiClient api;
  final ApiArticle article;
  final String bodyHtml;
  final Future<String> Function(String localPath)? uploadImage;

  static const Color pageBg = Color(0xFFF7F7F7);
  static const Color wechatGreen = Color(0xFF07C160);

  @override
  State<ArticlePublishPreparePage> createState() => _ArticlePublishPreparePageState();
}

class _ArticlePublishPreparePageState extends State<ArticlePublishPreparePage> {
  late String _coverUrl;
  late final TextEditingController _summaryController;
  late final TextEditingController _authorController;
  late bool _isOriginal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.article.coverImage;
    _summaryController = TextEditingController(text: widget.article.summary);
    _authorController = TextEditingController(
      text: widget.article.authorDisplay.isNotEmpty ? widget.article.authorDisplay : widget.article.author,
    );
    _isOriginal = widget.article.isOriginal;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final upload = widget.uploadImage;
    if (upload == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未配置图片上传')));
      }
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 88);
    if (x == null) return;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final url = await upload(x.path);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _coverUrl = url);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败：$e')));
      }
    }
  }

  Future<void> _saveDraft() async {
    await _persist(status: 'draft', popOnSuccess: false);
  }

  Future<void> _publish() async {
    await _persist(status: 'published', popOnSuccess: true);
  }

  Future<void> _persist({required String status, required bool popOnSuccess}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.saveArticle(
        id: widget.article.id,
        status: status,
        title: widget.article.title,
        bodyHtml: widget.bodyHtml,
        coverImage: _coverUrl,
        summary: _summaryController.text.trim(),
        authorDisplay: _authorController.text.trim(),
        isOriginal: _isOriginal,
      );
      if (!mounted) return;
      if (popOnSuccess) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存草稿')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPreview() {
    final preview = ApiArticle(
      id: widget.article.id,
      title: widget.article.title,
      bodyHtml: widget.bodyHtml,
      coverImage: _coverUrl,
      status: 'draft',
      createdAt: widget.article.createdAt,
      updatedAt: widget.article.updatedAt,
      publishedAt: widget.article.publishedAt,
      readCount: widget.article.readCount,
      author: widget.article.author,
      summary: _summaryController.text.trim(),
      authorDisplay: _authorController.text.trim(),
      isOriginal: _isOriginal,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailPage(article: preview),
      ),
    );
  }

  Widget _whiteCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ArticlePublishPreparePage.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _pickCover,
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _coverUrl.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add, size: 36, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text('轻触添加封面', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(_coverUrl, fit: BoxFit.cover),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('更换', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      widget.article.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _summaryController,
                      maxLines: 4,
                      minLines: 2,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      decoration: InputDecoration(
                        hintText: '输入摘要，选填',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _whiteCard(
                    children: [
                      _rowSwitch(
                        label: '原创',
                        value: _isOriginal,
                        onChanged: (v) => setState(() => _isOriginal = v),
                      ),
                      const Divider(height: 1),
                      _rowField(
                        label: '作者',
                        controller: _authorController,
                        hint: '输入作者名',
                      ),
                      const Divider(height: 1),
                      _rowChevron(
                        label: '留言',
                        subtitle: '留言和回复自动精选公开',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('敬请期待')));
                        },
                      ),
                      const Divider(height: 1),
                      _rowChevron(
                        label: '更多设置',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('敬请期待')));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
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
              child: Row(
                children: [
                  InkWell(
                    onTap: _saving ? null : _saveDraft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade700, size: 26),
                          const SizedBox(height: 2),
                          Text('存草稿', style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _showPreview,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        backgroundColor: const Color(0xFFEBEBEB),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('预览', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _publish,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('发表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: ArticlePublishPreparePage.wechatGreen.withValues(alpha: 0.45),
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _rowField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 16))),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowChevron({
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
