import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:path_provider/path_provider.dart';

class FilePathUtils {
  static Future<String> getPublicDownloadFolderPath() async {
    final folder = await _getPublicDownloadFolderPath();
    final dir = Directory(folder);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return folder;
  }

  static Future<String> _getPublicDownloadFolderPath() async {
    // 만약 다운로드 폴더가 존재하지 않는다면 앱내 파일 패스를 대신 주도록한다.
    if (Platform.isAndroid) {
      String? downloadDirPath =
          await ExternalPath.getExternalStoragePublicDirectory(
              ExternalPath.DIRECTORY_DOWNLOAD);
      Directory dir = Directory(downloadDirPath);

      if (!dir.existsSync()) {
        downloadDirPath = (await getExternalStorageDirectory())!.path;
      }
      return downloadDirPath;
    } else if (Platform.isIOS) {
      return (await getApplicationDocumentsDirectory()).path;
    } else {
      return (await getApplicationDocumentsDirectory()).path;
    }
  }

  static Future<String> getVideoDirectoryPath() async {
    final path = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_MOVIES);
    final dir = Directory(path);

    if (!await dir.exists()) {
      await dir.create(recursive: true); // 중요
    }
    return path;
  }
}
