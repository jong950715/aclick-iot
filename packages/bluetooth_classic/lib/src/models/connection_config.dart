/// 블루투스 연결 설정을 정의하는 클래스
class ConnectionConfig {
  /// 자동 재연결 시도 여부
  final bool autoReconnect;

  /// 연결 시도 제한 시간 (밀리초)
  final int connectionTimeout;
  
  /// 연결 시도 제한 시간 (밀리초) - 다른 이름으로도 사용
  int get connectionTimeoutMs => connectionTimeout;

  /// 연결 시도 최대 횟수
  final int maxConnectionAttempts;
  
  /// 연결 시도 최대 횟수 - 다른 이름으로도 사용
  int get maxReconnectAttempts => maxConnectionAttempts;

  /// 재연결 시도 간격 (밀리초)
  final int reconnectInterval;
  
  /// 재연결 시도 간격 (밀리초) - 다른 이름으로도 사용
  int get reconnectDelayMs => reconnectInterval;
  
  /// 버퍼 크기 (바이트)
  final int bufferSize;

  /// 기본 생성자
  const ConnectionConfig({
    this.autoReconnect = true,
    this.connectionTimeout = 10000,
    this.maxConnectionAttempts = 3,
    this.reconnectInterval = 5000,
    this.bufferSize = 4096, // 4KB
  });

  /// 기본 설정으로 인스턴스 생성
  factory ConnectionConfig.defaultConfig() {
    return const ConnectionConfig();
  }

  /// 재연결 없는 설정으로 인스턴스 생성
  factory ConnectionConfig.noReconnect() {
    return const ConnectionConfig(
      autoReconnect: false,
      maxConnectionAttempts: 1,
    );
  }

  /// 인스턴스 복사 및 속성 업데이트
  ConnectionConfig copyWith({
    bool? autoReconnect,
    int? connectionTimeout,
    int? maxConnectionAttempts,
    int? reconnectInterval,
    int? bufferSize,
  }) {
    return ConnectionConfig(
      autoReconnect: autoReconnect ?? this.autoReconnect,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      maxConnectionAttempts: maxConnectionAttempts ?? this.maxConnectionAttempts,
      reconnectInterval: reconnectInterval ?? this.reconnectInterval,
      bufferSize: bufferSize ?? this.bufferSize,
    );
  }

  @override
  String toString() {
    return 'ConnectionConfig('
        'autoReconnect: $autoReconnect, '
        'timeout: $connectionTimeout ms, '
        'maxAttempts: $maxConnectionAttempts, '
        'reconnectInterval: $reconnectInterval ms)';
  }
}
