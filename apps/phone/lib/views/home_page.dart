import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone/core/foreground_service_handler.dart';
import 'package:phone/services/ble_service.dart';
import 'package:phone/services/network_service.dart';
import 'package:phone/viewmodels/new_event_clip_view_model.dart';
import '../viewmodels/log_view_model.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) 포그라운드 위치 권한
      if (!await Permission.locationWhenInUse.isGranted) {
        final status = await Permission.locationWhenInUse.request();
        if (status != PermissionStatus.granted) {
          // 포그라운드 위치 권한 요청 거부 시 처리
        }
      }

      // 2) 백그라운드 위치 권한 (Android 10 이상 필요)
      if (!await Permission.locationAlways.isGranted) {
        final status = await Permission.locationAlways.request();
        if (status != PermissionStatus.granted) {
          // 백그라운드 위치 요청 거부 시 처리
        }
      }

      // 3) Android 12+ BLE 권한
      if (Platform.isAndroid && (await Permission.bluetoothScan.isDenied)) {
        final statusScan = await Permission.bluetoothScan.request();
        if (statusScan != PermissionStatus.granted) {
          // BLE 스캔 권한 거부 시 처리
        }
      }
      if (Platform.isAndroid && (await Permission.bluetoothConnect.isDenied)) {
        final statusConnect = await Permission.bluetoothConnect.request();
        if (statusConnect != PermissionStatus.granted) {
          // BLE 연결 권한 거부 시 처리
        }
      }
      if (Platform.isAndroid && (await Permission.bluetoothAdvertise.isDenied)) {
        final statusAdvertise = await Permission.bluetoothAdvertise.request();
        if (statusAdvertise != PermissionStatus.granted) {
          // BLE 광고 권한 거부 시 처리
        }
      }

      // 4) Android 13+ 주변 Wi-Fi 권한
      if (Platform.isAndroid && (await Permission.nearbyWifiDevices.isDenied)) {
        final statusWifi = await Permission.nearbyWifiDevices.request();
        if (statusWifi != PermissionStatus.granted) {
          // 주변 Wi-Fi 권한 거부 시 처리
        }
      }
      await Permission.location.request();


      await AppTaskHandler.requestPermissions();
      await AppTaskHandler.instance.startService();

    });
  }

  @override
  Widget build(BuildContext context) {
    final logViewModel = ref.read(logViewModelProvider.notifier);

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
