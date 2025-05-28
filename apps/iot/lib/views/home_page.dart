import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/repositories/app_logger.dart';
import 'package:iot/services/file_server_service.dart';
import 'package:iot/services/wifi_hotspot_service.dart';
import 'package:iot/services/ble_manager.dart';
import '../theme/app_theme.dart';
import 'control_buttons_view.dart';
import 'console_log_view.dart';

class HomePage extends ConsumerStatefulWidget {
  final String title;

  const HomePage({super.key, required this.title});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.watch(wifiHotspotServiceProvider);
      ref.watch(fileServerServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logViewModel = ref.read(appLoggerProvider.notifier);
    
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(
              Icons.devices_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Refresh connection',
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                onPressed: () {
                  logViewModel.logInfo('Refreshed at ${DateTime.now().toString().substring(11, 19)}');
                },
              ),
            ),
          ),
          Tooltip(
            message: 'Settings',
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.settings_rounded, color: Color(0xFF555555)),
                onPressed: () {
                  logViewModel.logDebug('Settings button pressed');
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 1 부분 - 버튼 영역 (1)
          const Flexible(
            flex: 2,
            child: ControlButtonsView(),
          ),
          
          // 하단 2 부분 - 콘솔 로그 영역 (2)
          const Flexible(
            flex: 5,
            child: ConsoleLogView(),
          ),
        ],
      ),
    );
  }
}
