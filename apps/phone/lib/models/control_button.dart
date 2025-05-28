import 'package:flutter/material.dart';

/// 컨트롤 버튼 데이터 모델
class ControlButton {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String logMessage;
  final VoidCallback onPressed;

  const ControlButton({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.logMessage,
    required this.onPressed,
  });
}
