import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static Directory? _appFolder;

  static Future<Directory> getAppFolder() async {
    if (_appFolder != null && await _appFolder!.exists()) return _appFolder!;

    Directory base;
    if (Platform.isAndroid) {
      // use app's external storage — no permissions needed on Android 10+
      final dirs = await getExternalStorageDirectories();
      base = dirs?.first ?? await getApplicationDocumentsDirectory();
    } else if (Platform.isMacOS || Platform.isWindows) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }

    final folder = Directory('${base.path}/Offline Era');
    if (!await folder.exists()) await folder.create(recursive: true);
    _appFolder = folder;
    return folder;
  }

  static Future<String> saveFile(String fileName, List<int> bytes) async {
    final folder = await getAppFolder();

    String finalName = fileName;
    File file = File('${folder.path}/$finalName');

    if (await file.exists()) {
      final dot = fileName.lastIndexOf('.');
      final name = dot != -1 ? fileName.substring(0, dot) : fileName;
      final ext = dot != -1 ? fileName.substring(dot) : '';
      int i = 1;
      while (await File('${folder.path}/${name}_$i$ext').exists()) i++;
      finalName = '${name}_$i$ext';
      file = File('${folder.path}/$finalName');
    }

    await file.writeAsBytes(bytes);
    return file.path;
  }
}
