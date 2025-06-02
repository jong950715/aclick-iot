import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/log_entry.dart';

// Riverpod 코드 생성을 위한 부분
part 'log_view_model.g.dart';

@riverpod
class LogViewModel extends _$LogViewModel {
  @override
  List<LogEntry> build() {
    FlutterForegroundTask.addTaskDataCallback((data) => logInfo('[foreground] $data'),);
    // 초기 로그 추가
    return [
      LogEntry.info('System initialized'),
    ];
  }

  void addLog(LogEntry log) {
    state = [...state, log];
  }

  void clearLogs() {
    state = [LogEntry.info('Console cleared')];
  }

  void logInfo(String message) {
    addLog(LogEntry.info(message));
  }

  void logDebug(String message) {
    addLog(LogEntry.debug(message));
  }

  void logWarning(String message) {
    addLog(LogEntry.warning(message));
  }

  void logError(String message) {
    addLog(LogEntry.error(message));
  }
}
