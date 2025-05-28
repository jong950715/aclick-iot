import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone/services/ble_service.dart';
import 'package:phone/services/network_service.dart';
import '../viewmodels/log_view_model.dart';
import '../theme/app_theme.dart';
import '../models/control_button.dart';

class ControlButtonsView extends ConsumerStatefulWidget {
  const ControlButtonsView({super.key});

  @override
  ConsumerState<ControlButtonsView> createState() => _ControlButtonsViewState();
}

class _ControlButtonsViewState extends ConsumerState<ControlButtonsView> {
  late final List<ControlButton> controlButtons;

  @override
  initState() {
    super.initState();
    controlButtons = [
      ControlButton(
        id: 'advertise',
        label: 'advertise',
        icon: Icons.bluetooth,
        color: AppTheme.primaryColor,
        logMessage: 'advertise Start',
        onPressed: () async {
          await ref.read(bleServiceProvider.notifier).startAdvertising();
        },
      ),
      ControlButton(
        id: 'connect',
        label: 'connect',
        icon: Icons.wifi,
        color: Colors.red,
        logMessage: 'Reset button pressed',
        onPressed: () {
          ref.read(networkServiceProvider.notifier).connectWifi();
        },
      ),
      ControlButton(
        id: 'scan//',
        label: 'Sca//n',
        icon: Icons.search,
        color: Colors.green,
        logMessage: 'Scan button pressed',
        onPressed: () {},
      ),
      ControlButton(
        id: 'send',
        label: 'Send',
        icon: Icons.send,
        color: Colors.orange,
        logMessage: 'Send button pressed',
        onPressed: () {
          ref.read(bleServiceProvider.notifier).sendNotification();
        },
      ),
      ControlButton(
        id: 'info',
        label: 'Information',
        icon: Icons.info_outline,
        color: AppTheme.secondaryColor,
        logMessage: 'Info button pressed',
        onPressed: () {},
      ),
      ControlButton(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings,
        color: Colors.teal,
        logMessage: 'Settings button pressed',
        onPressed: () {},
      ),
      ControlButton(
        id: 'sync',
        label: 'Sync',
        icon: Icons.sync,
        color: Colors.indigo,
        logMessage: 'Sync button pressed',
        onPressed: () {},
      ),
      ControlButton(
        id: 'help',
        label: 'Help',
        icon: Icons.help_outline,
        color: Colors.deepPurple,
        logMessage: 'Help button pressed',
        onPressed: () {},
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final logViewModel = ref.read(logViewModelProvider.notifier);

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
}
