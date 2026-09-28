import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import 'local_backup_service.dart';

class GoogleDriveBackupService {
  static const _scope = 'https://www.googleapis.com/auth/drive.appdata';

  Future<GoogleSignInAccount> _account() async {
    final signIn = GoogleSignIn(scopes: const [_scope]);
    final current = signIn.currentUser ?? await signIn.signInSilently();
    final account = current ?? await signIn.signIn();
    if (account == null) throw StateError('ورود به حساب گوگل لغو شد.');
    return account;
  }

  Future<_GoogleAuthClient> _client() async {
    final account = await _account();
    final auth = await account.authentication;
    if (auth.accessToken == null) throw StateError('توکن Google Drive دریافت نشد.');
    return _GoogleAuthClient(auth.accessToken!);
  }

  Future<void> uploadBackup() async {
    final backup = await LocalBackupService().createBackup();
    final client = await _client();

    try {
      final api = drive.DriveApi(client);
      final media = drive.Media(backup.openRead(), await backup.length());
      final existing = await api.files.list(
        spaces: 'appDataFolder',
        q: "name='tamrino_latest.db'",
        $fields: 'files(id,name)',
      );

      if (existing.files?.isNotEmpty == true) {
        await api.files.update(
          drive.File()..name = 'tamrino_latest.db',
          existing.files!.first.id!,
          uploadMedia: media,
        );
      } else {
        await api.files.create(
          drive.File()
            ..name = 'tamrino_latest.db'
            ..parents = const ['appDataFolder'],
          uploadMedia: media,
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> restoreLatest() async {
    final client = await _client();

    try {
      final api = drive.DriveApi(client);
      final files = await api.files.list(
        spaces: 'appDataFolder',
        q: "name='tamrino_latest.db'",
        orderBy: 'modifiedTime desc',
        pageSize: 1,
        $fields: 'files(id,name,modifiedTime)',
      );

      if (files.files?.isNotEmpty != true) {
        throw StateError('هیچ بکاپی در Google Drive پیدا نشد.');
      }

      final media = await api.files.get(
        files.files!.first.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      await LocalBackupService().createBackup();
      await AppDatabase.instance.close();
      final sink = File(await AppDatabase.instance.databasePath()).openWrite();
      await media.stream.pipe(sink);
      await AppDatabase.instance.reopen();
    } finally {
      client.close();
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this.token);

  final String token;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
