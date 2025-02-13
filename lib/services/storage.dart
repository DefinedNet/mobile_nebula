import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class Storage {
  Future<Directory> mkdir(String path) async {
    final parent = await localPath;
    return Directory(p.join(parent, path)).create(recursive: true);
  }

  Future<List<FileSystemEntity>> listDir(String path) async {
    List<FileSystemEntity> list = [];
    var parent = await localPath;

    if (path != '') {
      parent = p.join(parent, path);
    }

    var completer = Completer<List<FileSystemEntity>>();

    Directory(parent)
        .list()
        .listen((FileSystemEntity entity) {
          list.add(entity);
        })
        .onDone(() {
          completer.complete(list);
        });

    return completer.future;
  }

  Future<String> get localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<String?> readFile(String path) async {
    try {
      final parent = await localPath;
      final file = File(p.join(parent, path));

      // Read the file
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }

  Future<File> writeFile(String path, String contents) async {
    final parent = await localPath;
    final file = File(p.join(parent, path));

    // Write the file
    return file.writeAsString(contents);
  }

  Future delete(String path) async {
    var parent = await localPath;
    return File(p.join(parent, path)).delete(recursive: true);
  }

  Future getFullPath(String path) async {
    var parent = await localPath;
    return p.join(parent, path);
  }
}
