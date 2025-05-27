import 'package:flutter/material.dart';

class AppTheme {
  // 색상 정의
  static const Color primaryColor = Color(0xFF0070F3);
  static const Color secondaryColor = Color(0xFF7928CA);
  static const Color accentColor = Color(0xFF50E3C2);
  static const Color errorColor = Color(0xFFFF0000);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color infoColor = Color(0xFF2196F3);
  static const Color textColor = Color(0xFF333333);
  
  // 배경색
  static const Color scaffoldBackground = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color consoleBackground = Color(0xFF1E1E1E);
  static const Color consolePanelBackground = Color(0xFF252525);
  
  // 테마 데이터
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      background: scaffoldBackground,
    ),
    scaffoldBackgroundColor: scaffoldBackground,
    fontFamily: 'Inter',
    
    // AppBar 테마
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: textColor,
      centerTitle: false,
      shape: Border(
        bottom: BorderSide(
          color: Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
    ),
    
    // 버튼 테마
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    // 카드 테마
    cardTheme: CardThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withOpacity(0.1),
    ),
    
    // 텍스트 테마
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textColor,
      ),
    ),
    
    // 아이콘 테마
    iconTheme: const IconThemeData(
      color: primaryColor,
      size: 24,
    ),
  );
  
  // 공통 그림자
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  // 콘솔 텍스트 스타일
  static TextStyle consoleTextStyle(Color color) {
    return TextStyle(
      color: color,
      fontFamily: 'JetBrainsMono',
      fontSize: 14,
      height: 1.5,
    );
  }
  
  // 콘솔 로그 색상
  static Color getLogColor(String logLevel) {
    switch (logLevel.toUpperCase()) {
      case 'INFO':
        return const Color(0xFF58A6FF);
      case 'DEBUG':
        return const Color(0xFF8B949E);
      case 'WARNING':
        return const Color(0xFFF0883E);
      case 'ERROR':
        return const Color(0xFFF85149);
      default:
        return const Color(0xFF58A6FF);
    }
  }
}
