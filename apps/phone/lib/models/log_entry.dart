class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.level,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LogEntry.info(String message) {
    return LogEntry(
      message: message,
      level: LogLevel.info,
    );
  }

  factory LogEntry.debug(String message) {
    return LogEntry(
      message: message,
      level: LogLevel.debug,
    );
  }

  factory LogEntry.warning(String message) {
    return LogEntry(
      message: message,
      level: LogLevel.warning,
    );
  }

  factory LogEntry.error(String message) {
    return LogEntry(
      message: message,
      level: LogLevel.error,
    );
  }

  String get formattedMessage {
    final levelTag = '[${level.name.toUpperCase()}]';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    return '$levelTag [$timeStr] $message';
  }
}

enum LogLevel {
  info,
  debug,
  warning,
  error,
}
