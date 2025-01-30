import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/services/result.dart';

class LogsNotFoundException implements Exception {
  String error() => 'No logs file found';
}

class LogsNotifier extends ChangeNotifier {
  Result<String>? logsResult;

  LogsNotifier();

  loadLogs({required String logFile}) async {
    final file = File(logFile);
    try {
      logsResult = Result.ok(await file.readAsString());
      notifyListeners();
    } on FileSystemException {
      logsResult = Result.error(LogsNotFoundException());
      notifyListeners();
    } on Exception catch (err) {
      logsResult = Result.error(err);
      notifyListeners();
    } catch (err) {
      logsResult = Result.error(Exception(err));
      notifyListeners();
    }
  }
}
