import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../models/article_model.dart';
import '../services/api_client.dart';
import 'article_publish_prepare_page.dart';

/// 类微信公众号：全屏编辑正文，保存为 HTML 供后端存储
class ArticleRichEditorPage extends StatefulWidget {
  const ArticleRichEditorPage({
    super.key,
    required this.api,
    required this.initialTitle,
    required this.initialHtml,
    required this.isEdit,
    required this.onSaveDraft,
    required this.onUpsertDraft,
    this.uploadImage,
  });

  final ApiClient api;
  final String initialTitle;
  final String initialHtml;
  final bool isEdit;
  final Future<void> Function(String title, String bodyHtml) onSaveDraft;
  /// 保存草稿并返回文章（用于进入「发表前」页）
  final Future<ApiArticle> Function(String title, String bodyHtml) onUpsertDraft;

  /// 选图后上传到服务端，返回可嵌入正文的公开 URL；为 null 时不显示工具栏「图片」按钮。
  final Future<String> Function(String localPath)? uploadImage;

  static const Color inkBlack = Color(0xFF000000);
  static const Color pageBg = Color(0xFFFFFFFF);
  static const Color toolbarBg = Color(0xFFF0F2F5);

  @override
  State<ArticleRichEditorPage> createState() => _ArticleRichEditorPageState();
}

class _ArticleRichEditorPageState extends State<ArticleRichEditorPage> {
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _quillController = QuillController(
      document: _documentFromHtml(widget.initialHtml),
      selection: const TextSelection.collapsed(offset: 0),
      config: const QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          enableExternalRichPaste: true,
        ),
      ),
    );
  }

  Document _documentFromHtml(String html) {
    final t = html.trim();
    if (t.isEmpty) {
      return Document();
    }
    try {
      final delta = HtmlToDelta().convert(t);
      return Document.fromDelta(delta);
    } catch (_) {
      return Document.fromJson([
        {'insert': '$t\n'},
      ]);
    }
  }

  String _bodyHtml() {
    final ops = _quillController.document.toDelta().toJson();
    return QuillDeltaToHtmlConverter(ops).convert();
  }

  bool _bodyIsEffectivelyEmpty() {
    return _quillController.document.toPlainText().trim().isEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  Future<String?> _onRequestPickImage(BuildContext context) async {
    final upload = widget.uploadImage;
    if (upload == null) return null;

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
    if (source == null) return null;

    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 88,
    );
    if (xfile == null) return null;

    if (!context.mounted) return null;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('上传图片中…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final url = await upload(xfile.path);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return url;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e')),
        );
      }
      return null;
    }
  }

  Future<void> _runSave(Future<void> Function(String title, String html) fn) async {
    final title = _titleController.text.trim();
    final body = _bodyHtml();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('标题不能为空')));
      }
      return;
    }
    if (_bodyIsEffectivelyEmpty()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正文不能为空')));
      }
      return;
    }
    try {
      await fn(title, body);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _onNext() async {
    final title = _titleController.text.trim();
    final body = _bodyHtml();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('标题不能为空')));
      }
      return;
    }
    if (_bodyIsEffectivelyEmpty()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正文不能为空')));
      }
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final art = await widget.onUpsertDraft(title, body);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final published = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (ctx) => ArticlePublishPreparePage(
            api: widget.api,
            article: art,
            bodyHtml: body,
            uploadImage: widget.uploadImage,
          ),
        ),
      );
      if (published == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  DefaultStyles _editorStyles(BuildContext context) {
    final theme = DefaultStyles.getInstance(context);
    final p = theme.paragraph!;
    return theme.merge(
      DefaultStyles(
        paragraph: DefaultTextBlockStyle(
          p.style.copyWith(
            fontSize: 17,
            height: 1.75,
            color: const Color(0xFF333333),
          ),
          p.horizontalSpacing,
          const VerticalSpacing(6, 0),
          const VerticalSpacing(0, 10),
          null,
        ),
        placeHolder: DefaultTextBlockStyle(
          TextStyle(
            fontSize: 17,
            height: 1.75,
            color: Colors.grey.shade400,
          ),
          const HorizontalSpacing(0, 0),
          VerticalSpacing.zero,
          VerticalSpacing.zero,
          null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: ArticleRichEditorPage.pageBg,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ArticleRichEditorPage.pageBg,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: ArticleRichEditorPage.pageBg,
          foregroundColor: ArticleRichEditorPage.inkBlack,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            widget.isEdit ? '编辑文章' : '写文章',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () => _runSave(widget.onSaveDraft),
              style: TextButton.styleFrom(foregroundColor: ArticleRichEditorPage.inkBlack),
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 2),
              child: TextButton(
                onPressed: _onNext,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF333333),
                  backgroundColor: const Color(0xFFEBEBEB),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('下一步', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.35,
                ),
                decoration: const InputDecoration(
                  hintText: '请填写标题',
                  hintStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFC8C8C8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.only(bottom: 12),
                ),
                onSubmitted: (_) => _editorFocus.requestFocus(),
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            Expanded(
              child: QuillEditor(
                focusNode: _editorFocus,
                scrollController: _editorScroll,
                controller: _quillController,
                config: QuillEditorConfig(
                  placeholder: '从这里开始写正文…',
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  customStyles: _editorStyles(context),
                  embedBuilders: FlutterQuillEmbeds.editorBuilders(
                    imageEmbedConfig: const QuillEditorImageEmbedConfig(),
                    videoEmbedConfig: null,
                  ),
                ),
              ),
            ),
            // 放在 body 内而非 bottomNavigationBar，才能随键盘顶起（避免被输入法盖住）
            Material(
              color: ArticleRichEditorPage.toolbarBg,
              elevation: 8,
              shadowColor: Colors.black26,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '收起键盘',
                      onPressed: () => FocusScope.of(context).unfocus(),
                      icon: const Icon(Icons.keyboard_hide_outlined, color: ArticleRichEditorPage.inkBlack),
                    ),
                    const SizedBox(
                      height: 28,
                      child: VerticalDivider(width: 1, thickness: 1, color: Color(0xFFDDE1E6)),
                    ),
                    Expanded(
                      child: QuillSimpleToolbar(
                        controller: _quillController,
                        config: QuillSimpleToolbarConfig(
                          color: ArticleRichEditorPage.toolbarBg,
                          sectionDividerColor: const Color(0xFFDDE1E6),
                          iconTheme: const QuillIconTheme(
                            iconButtonUnselectedData: IconButtonData(color: ArticleRichEditorPage.inkBlack),
                          ),
                          multiRowsDisplay: false,
                          axis: Axis.horizontal,
                          toolbarSize: 22,
                          showClipboardPaste: true,
                          showSearchButton: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showFontFamily: false,
                          showFontSize: false,
                          buttonOptions: QuillSimpleToolbarButtonOptions(
                            base: QuillToolbarBaseButtonOptions(
                              iconSize: 20,
                              iconButtonFactor: 1.45,
                              iconTheme: const QuillIconTheme(
                                iconButtonUnselectedData: IconButtonData(color: ArticleRichEditorPage.inkBlack),
                              ),
                            ),
                          ),
                          embedButtons: FlutterQuillEmbeds.toolbarButtons(
                            imageButtonOptions: widget.uploadImage == null
                                ? null
                                : QuillToolbarImageButtonOptions(
                                    imageButtonConfig: QuillToolbarImageConfig(
                                      onRequestPickImage: _onRequestPickImage,
                                    ),
                                    iconTheme: const QuillIconTheme(
                                      iconButtonUnselectedData: IconButtonData(color: ArticleRichEditorPage.inkBlack),
                                    ),
                                  ),
                            videoButtonOptions: null,
                            cameraButtonOptions: null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
