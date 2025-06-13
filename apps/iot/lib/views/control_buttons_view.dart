import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/repositories/app_logger.dart';
import 'package:iot/services/event_clip_saver.dart';
import 'package:iot/services/event_handler.dart';
import 'package:iot/services/file_server_service.dart';
import 'package:iot/services/wifi_hotspot_service.dart';
import 'package:iot/services/ble_manager.dart';
import 'package:iot/viewmodels/app_view_model.dart';
import '../services/video_recording_service.dart';
import '../theme/app_theme.dart';
import '../models/control_button.dart';

class ControlButtonsView extends ConsumerStatefulWidget {
  const ControlButtonsView({super.key});

  @override
  ConsumerState<ControlButtonsView> createState() => _ControlButtonsViewState();
}

class _ControlButtonsViewState extends ConsumerState<ControlButtonsView> {
  late final List<ControlButton> controlButtons;
  AppViewModel get _vm => ref.read(appViewModelProvider.notifier);

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
    controlButtons = [
      ControlButton(
        id: 'scan',
        label: '1.scan\n15s',
        icon: Icons.search,
        color: Colors.green,
        logMessage: 'Scan Start pressed',
        onPressed: () async {
          await scan();
        },
      ),
      ControlButton(
        id: 'connect',
        label: '2.connect',
        icon: Icons.bluetooth,
        color: AppTheme.primaryColor,
        logMessage: 'connect button pressed',
        onPressed: () async {
          await connect();
        },
      ),
      ControlButton(
        id: 'hotspot',
        label: '3.hotspot',
        icon: Icons.wifi,
        color: Colors.tealAccent,
        logMessage: 'hotspot button pressed',
        onPressed: () async {
          await ref.read(wifiHotspotServiceProvider.notifier).startHotspot();
        },
      ),
      ControlButton(
        id: 'send',
        label: '4.send\nssid/pw',
        icon: Icons.send,
        color: Colors.purpleAccent,
        logMessage: 'Send wifi pressed',
        onPressed: () async {
          _vm.sendWifiCredential();
        },
      ),
      ControlButton(
        id: 'start server',
        label: '5.start\nserver',
        icon: Icons.miscellaneous_services,
        color: Colors.teal,
        logMessage: 'start server button pressed',
        onPressed: () {
          ref.read(fileServerServiceProvider.notifier).startServer();
        },
      ),
      ControlButton(
        id: 'record',
        label: '6.record',
        icon: Icons.fiber_smart_record,
        color: Colors.red,
        logMessage: 'record button pressed',
        onPressed: () {
          ref.read(videoRecordingServiceProvider).startRecording();
        },
      ),
      ControlButton(
        id: 'emit event',
        label: '7.emit event',
        icon: Icons.ac_unit,
        color: Colors.indigo,
        logMessage: 'emit event button pressed',
        onPressed: () {
          ref.read(eventHandlerProvider.notifier).captureEvent();
        },
      ),
      ControlButton(
        id: 'ping',
        label: 'ping',
        icon: Icons.network_ping,
        color: Colors.orange,
        logMessage: 'ping button pressed',
        onPressed: () async {
          await ping();
        },
      ),
      ControlButton(
        id: 'disconnect',
        label: 'disconnect',
        icon: Icons.cancel_outlined,
        color: Colors.green,
        logMessage: 'disconnect button pressed',
        onPressed: () async {
          await ref.read(bleManagerProvider.notifier).disconnect();
        },
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final logViewModel = ref.read(appLoggerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: controlButtons.length,
          itemBuilder: (context, index) {
            final button = controlButtons[index];
            return _buildControlButton(
              button.label,
              button.icon,
              button.color,
              () {
                logViewModel.logInfo(button.logMessage);
                button.onPressed();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 65, // 버튼 높이 증가
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: color.withOpacity(0.12),
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> scan() async {
    await ref
        .read(bleManagerProvider.notifier)
        .scanDuration(Duration(seconds: 15));
  }

  Future<void> connect() async {
    await ref.read(bleManagerProvider.notifier).connect();
  }

  Future<void> ping() async {
    await ref.read(bleManagerProvider.notifier).ping();
  }
}
