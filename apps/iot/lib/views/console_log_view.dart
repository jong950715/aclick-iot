import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/repositories/app_logger.dart';
import '../models/log_entry.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class ConsoleLogView extends ConsumerWidget {
  const ConsoleLogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(appLoggerProvider);
    final appLogger = ref.read(appLoggerProvider.notifier);
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.consoleBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.consolePanelBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  color: Colors.white60,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'CONSOLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Copy logs',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_outlined, color: Colors.white60),
                      onPressed: () {
                        appLogger.logInfo('Logs copied to clipboard');
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Clear logs',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.clear_all, color: Colors.white60),
                      onPressed: () => appLogger.clearLogs(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.consoleBackground,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  Color textColor;
                  IconData? iconData;
                  
                  switch (log.level) {
                    case LogLevel.warning:
                      textColor = AppTheme.warningColor;
                      iconData = Icons.warning_amber_rounded;
                      break;
                    case LogLevel.error:
                      textColor = AppTheme.errorColor;
                      iconData = Icons.error_outline;
                      break;
                    case LogLevel.debug:
                      textColor = Colors.grey.shade400;
                      iconData = Icons.code;
                      break;
                    case LogLevel.info:
                    default:
                      textColor = AppTheme.infoColor;
                      iconData = Icons.info_outline;
                      break;
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          iconData,
                          size: 16,
                          color: textColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: textColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      log.level.name.toUpperCase(),
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                log.message,
                                style: TextStyle(
                                  color: Colors.grey[100],
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
