import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone/services/ble_service.dart';
import 'package:phone/services/network_service.dart';
import 'package:phone/viewmodels/new_event_clip_view_model.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AppTaskHandler.instance);
}

class AppTaskHandler extends TaskHandler {
  AppTaskHandler._();
  static final AppTaskHandler instance = AppTaskHandler._();

  final ProviderContainer _bgContainer = ProviderContainer();
  BleService get _ble => _bgContainer.read(bleServiceProvider.notifier);
  NetworkService get _network => _bgContainer.read(networkServiceProvider.notifier);
  NewEventClipViewModel get _newEventClip => _bgContainer.read(newEventClipViewModelProvider.notifier);
  DebugPrintNotifier get _debugPrint => _bgContainer.read(debugPrintProvider.notifier);

  void _log(String message) => FlutterForegroundTask.sendDataToMain(message);

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _bgContainer.dispose();
    print('onDestroy(isTimeout: $isTimeout)');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.updateService();
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('onStart(starter: ${starter.name})');
  }

  static Future<void> requestPermissions() async {
    // Android 13+, you need to allow notification permission to display foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // Android 12+, there are restrictions on starting a foreground service.
      //
      // To restart the service on device reboot or unexpected problem, you need to allow below permission.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      // Use this utility only if you provide services that require long-term survival,
      // such as exact alarm service, healthcare service, or Bluetooth communication.
      //
      // This utility requires the "android.permission.SCHEDULE_EXACT_ALARM" permission.
      // Using this permission may make app distribution difficult due to Google policy.
      if (!await FlutterForegroundTask.canScheduleExactAlarms) {
        // When you call this function, will be gone to the settings page.
        // So you need to explain to the user why set it.
        await FlutterForegroundTask.openAlarmsAndRemindersSettings();
      }
    }
  }

  static void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'Aclick_notification_channel_id',
        channelName: 'Aclick Notification Channel',
        channelDescription:
            'This notification appears when the foreground service is running.',
        onlyAlertOnce: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<ServiceRequestResult> startService() async {
    _initService();
    _debugPrint.start(_log);
    _newEventClip.initialize();

    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        // You can manually specify the foregroundServiceType for the service
        // to be started, as shown in the comment below.
        // serviceTypes: [
        //   ForegroundServiceTypes.dataSync,
        //   ForegroundServiceTypes.remoteMessaging,
        // ],
        serviceId: 0x2fbec451,
        // serviceTypes: [
        //   ForegroundServiceTypes.location,
        //   ForegroundServiceTypes.connectedDevice,
        //   ForegroundServiceTypes.remoteMessaging,
        // ],
        notificationTitle: 'Aclick 타이틀',
        notificationText: 'Aclick 노티 텍스트',
        notificationIcon: null,
        notificationButtons: [
          const NotificationButton(id: 'btn1', text: 'hello1'),
          const NotificationButton(id: 'btn2', text: 'hello2'),
          const NotificationButton(id: 'btn3', text: 'hello3'),
        ],
        // notificationInitialRoute: '/',
        callback: startCallback,
      );
    }
  }

  static Future<ServiceRequestResult> stopService() {
    return FlutterForegroundTask.stopService();
  }
}

/// 디버깅용
final debugPrintProvider = NotifierProvider<DebugPrintNotifier, void>(
  DebugPrintNotifier.new,
);

class DebugPrintNotifier extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    // Provider가 처음 구독됐을 때 한 번 실행됩니다.
  }

  void start(void Function (String msg) callback) {
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      final msg = '🛠️ DebugPrintNotifier: ${DateTime.now()}';
      print(msg);
      callback(msg);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
