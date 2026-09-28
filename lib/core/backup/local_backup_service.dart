import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

class LocalBackupService {
  Future<File> createBackup() async {
    await AppDatabase.instance.close();

    final dbFile = File(await AppDatabase.instance.databasePath());
    if (!await dbFile.exists()) {
      await AppDatabase.instance.reopen();
      throw StateError('فایل دیتابیس پیدا نشد.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    await backupDir.create(recursive: true);

    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final out = File('${backupDir.path}/tamrino_backup_$stamp.db');
    await dbFile.copy(out.path);

    await AppDatabase.instance.reopen();
    return out;
  }

  Future<String?> exportBackup() async {
    final backup = await createBackup();
    return FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره نسخه پشتیبان تمرینو',
      fileName: backup.uri.pathSegments.last,
      type: FileType.custom,
      allowedExtensions: ['db'],
      bytes: await backup.readAsBytes(),
    );
  }

  Future<void> restoreFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result == null || result.files.single.path == null) return;

    final picked = File(result.files.single.path!);
    if (!await picked.exists()) throw StateError('فایل قابل خواندن نیست.');

    await createBackup();
    await AppDatabase.instance.close();
    await picked.copy(await AppDatabase.instance.databasePath());
    await AppDatabase.instance.reopen();
  }
}
