import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'app_config.dart';

class DownloadProgress {
  final String fileName;
  final int received;
  final int total;
  final int fileIndex;
  final int fileCount;
  const DownloadProgress({
    required this.fileName,
    required this.received,
    required this.total,
    required this.fileIndex,
    required this.fileCount,
  });

  double get fraction => total <= 0 ? 0 : received / total;
}

class ModelRepository {
  final Dio _dio = Dio();
  Directory? _dir;

  Future<Directory> _modelsDir() async {
    if (_dir != null) return _dir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/models');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<File> fileFor(ModelSpec spec) async {
    final dir = await _modelsDir();
    return File('${dir.path}/${spec.fileName}');
  }

  Future<bool> isValid(ModelSpec spec) async {
    final file = await fileFor(spec);
    if (!await file.exists()) return false;
    if (await file.length() != spec.size) return false;
    return true;
  }

  Future<bool> verifyHash(ModelSpec spec) async {
    final file = await fileFor(spec);
    if (!await file.exists()) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == spec.sha256;
  }

  Future<bool> allReady() async {
    for (final spec in AppConfig.all) {
      if (!await isValid(spec)) return false;
    }
    return true;
  }

  Future<void> ensureModels(void Function(DownloadProgress) onProgress) async {
    for (var i = 0; i < AppConfig.all.length; i++) {
      final spec = AppConfig.all[i];
      if (await isValid(spec)) continue;
      await _download(spec, i, AppConfig.all.length, onProgress);
      if (!await verifyHash(spec)) {
        final f = await fileFor(spec);
        if (await f.exists()) await f.delete();
        throw Exception('Checksum mismatch for ${spec.fileName}');
      }
    }
  }

  Future<void> _download(
    ModelSpec spec,
    int index,
    int count,
    void Function(DownloadProgress) onProgress,
  ) async {
    final file = await fileFor(spec);
    final tmp = File('${file.path}.part');
    if (await tmp.exists()) await tmp.delete();

    await _dio.download(
      spec.url(AppConfig.hfRepoBase),
      tmp.path,
      onReceiveProgress: (received, total) {
        onProgress(DownloadProgress(
          fileName: spec.fileName,
          received: received,
          total: total > 0 ? total : spec.size,
          fileIndex: index,
          fileCount: count,
        ));
      },
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 30),
      ),
    );

    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }
}
