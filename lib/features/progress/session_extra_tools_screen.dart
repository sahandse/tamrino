import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/open_gym_feature_repository.dart';

class SessionExtraToolsScreen extends StatefulWidget {
  const SessionExtraToolsScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  final int sessionId;
  final String sessionName;

  @override
  State<SessionExtraToolsScreen> createState() => _SessionExtraToolsScreenState();
}

class _SessionExtraToolsScreenState extends State<SessionExtraToolsScreen> {
  final features = OpenGymFeatureRepository();

  Future<void> _copyText() async {
    final text = await features.sessionAsText(widget.sessionId);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خلاصه تمرین کپی شد.')),
      );
    }
  }

  Future<void> _saveAsRoutine() async {
    final controller = TextEditingController(text: '${widget.sessionName} - برنامه');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ذخیره به‌عنوان برنامه'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'نام برنامه'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ساخت برنامه'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await features.saveSessionAsRoutine(sessionId: widget.sessionId, name: name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برنامه از روی این جلسه ساخته شد.')),
      );
    }
  }

  Future<void> _addAttachment() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'webm'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    if (file.path == null) return;
    final ext = (file.extension ?? '').toLowerCase();
    final type = {'mp4', 'webm'}.contains(ext)
        ? 'video'
        : ext == 'gif'
            ? 'gif'
            : 'image';
    await features.addAttachment(
      sessionId: widget.sessionId,
      filePath: file.path!,
      mediaType: type,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ابزارهای جلسه')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: features.attachmentsForSession(widget.sessionId),
          builder: (context, snapshot) {
            final attachments = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.content_copy_rounded),
                      title: const Text('کپی تمرین به‌صورت متن'),
                      subtitle: const Text('خلاصه ست‌ها و فعالیت‌ها برای اشتراک دستی'),
                      onTap: _copyText,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.bookmark_add_outlined),
                      title: const Text('ذخیره به‌عنوان برنامه'),
                      subtitle: const Text('حرکت‌ها و تعداد ست‌ها را به یک برنامه جدید تبدیل می‌کند'),
                      onTap: _saveAsRoutine,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Text('ضمیمه‌های جلسه', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _addAttachment,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('افزودن'),
                  ),
                ]),
                const SizedBox(height: 10),
                if (attachments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('هنوز عکس یا ویدئویی به این جلسه وصل نشده است.'),
                    ),
                  )
                else
                  ...attachments.map(
                    (attachment) => Card(
                      child: ListTile(
                        leading: Icon(
                          attachment['media_type'] == 'video'
                              ? Icons.videocam_outlined
                              : Icons.image_outlined,
                        ),
                        title: Text(
                          (attachment['file_path'] as String).split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(attachment['media_type'] as String? ?? 'media'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            await features.deleteAttachment(attachment['id'] as int);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
