import 'package:flutter_riverpod/flutter_riverpod.dart';

final consoleProvider = StateNotifierProvider<ConsoleNotifier, List<String>>(
      (ref) => ConsoleNotifier(),
);

/// 1) StateNotifier: 로그 목록을 관리
class ConsoleNotifier extends StateNotifier<List<String>> {
  ConsoleNotifier(): super([]);

  /// 로그 추가
  void addLog(String log) {
    state = [...state, log];
  }

  /// 로그 초기화(필요 시)
  void clear() {
    state = [];
  }
}