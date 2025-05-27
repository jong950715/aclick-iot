import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/log_view_model.dart';
import '../theme/app_theme.dart';

class ControlButtonsView extends ConsumerWidget {
  const ControlButtonsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 첫번째 줄 버튼 그룹 (2개)
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    'Connect',
                    Icons.bluetooth,
                    Colors.blue,
                    () => logViewModel.logInfo('Connect button pressed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    'Scan',
                    Icons.search,
                    Colors.green,
                    () => logViewModel.logInfo('Scan button pressed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 두번째 줄 버튼 그룹 (2개)
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    'Send',
                    Icons.send,
                    Colors.orange,
                    () => logViewModel.logInfo('Send button pressed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    'Reset',
                    Icons.restart_alt,
                    Colors.red,
                    () => logViewModel.logInfo('Reset button pressed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 세번째 줄 버튼 그룹 (1개)
            _buildControlButton(
              'Information',
              Icons.info_outline,
              AppTheme.secondaryColor,
              () => logViewModel.logInfo('Info button pressed'),
            ),
          ],
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
