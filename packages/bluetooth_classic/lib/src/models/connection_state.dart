import 'package:bluetooth_classic/bluetooth_classic.dart';

/// Represents the various states a Bluetooth connection can be in.
enum BluetoothConnectionState {
  /// No connection has been established
  disconnected,

  /// Currently attempting to establish a connection
  connecting,

  /// Connection is established and ready for data transfer
  connected,

  /// Connection is active and data is being transferred
  transferring,

  /// Connection is being terminated
  disconnecting,

  /// Error occurred during connection or data transfer
  error,

  /// Failed
  failed,
}

/// Represents the data transfer statistics for a Bluetooth connection
class ConnectionStats {
  /// Total number of bytes received since connection was established
  final int bytesReceived;

  /// Total number of bytes sent since connection was established
  final int bytesSent;

  /// Total number of successful packets received
  final int packetsReceived;

  /// Total number of successful packets sent
  final int packetsSent;

  /// Number of errors encountered during data transfer
  final int errorCount;

  /// Average latency in milliseconds for round-trip communication
  final double averageLatencyMs;

  /// Signal strength in dBm
  final int? rssi;

  /// Timestamp when connection was established
  final DateTime? connectedAt;

  /// Default constructor
  const ConnectionStats({
    this.bytesReceived = 0,
    this.bytesSent = 0,
    this.packetsReceived = 0,
    this.packetsSent = 0,
    this.errorCount = 0,
    this.averageLatencyMs = 0.0,
    this.rssi,
    this.connectedAt,
  });

  /// Create a copy with updated properties
  ConnectionStats copyWith({
    int? bytesReceived,
    int? bytesSent,
    int? packetsReceived,
    int? packetsSent,
    int? errorCount,
    double? averageLatencyMs,
    int? rssi,
    DateTime? connectedAt,
  }) {
    return ConnectionStats(
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesSent: bytesSent ?? this.bytesSent,
      packetsReceived: packetsReceived ?? this.packetsReceived,
      packetsSent: packetsSent ?? this.packetsSent,
      errorCount: errorCount ?? this.errorCount,
      averageLatencyMs: averageLatencyMs ?? this.averageLatencyMs,
      rssi: rssi ?? this.rssi,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  /// Record bytes received
  ConnectionStats recordBytesReceived(int bytes) {
    return copyWith(
      bytesReceived: bytesReceived + bytes,
      packetsReceived: packetsReceived + 1,
    );
  }

  /// Record bytes sent
  ConnectionStats recordBytesSent(int bytes) {
    return copyWith(
      bytesSent: bytesSent + bytes,
      packetsSent: packetsSent + 1,
    );
  }

  /// Record error
  ConnectionStats recordError() {
    return copyWith(
      errorCount: errorCount + 1,
    );
  }

  /// Updates the average latency using an exponential moving average
  ConnectionStats updateLatency(double latencyMs) {
    // Use exponential moving average for smoother updates
    // with weight of 0.2 for new values
    const weight = 0.2;
    final newAverage = averageLatencyMs == 0.0
        ? latencyMs
        : averageLatencyMs * (1 - weight) + latencyMs * weight;

    return copyWith(
      averageLatencyMs: newAverage,
    );
  }
}

/// Bluetooth 연결 이벤트를 나타내는 sealed class
sealed class BluetoothConnectionEvent {
  const BluetoothConnectionEvent();

  factory BluetoothConnectionEvent.connect(BluetoothConnection connection) =
      BluetoothConnectedEvent;

  factory BluetoothConnectionEvent.disconnect(String address) =
      BluetoothDisconnectedEvent;

  factory BluetoothConnectionEvent.fail(String address, {String? error}) =
      BluetoothConnectionFailedEvent;

  /// 장치 주소 getter
  String? get address;
}

/// 블루투스 연결 성공 이벤트
final class BluetoothConnectedEvent extends BluetoothConnectionEvent {
  final BluetoothConnection _connection;

  const BluetoothConnectedEvent(this._connection);

  BluetoothConnection get connection => _connection;

  @override
  String? get address => connection.device.address;
}

/// 블루투스 연결 해제 이벤트
final class BluetoothDisconnectedEvent extends BluetoothConnectionEvent {
  final String _address;

  const BluetoothDisconnectedEvent(this._address);

  @override
  String get address => _address;
}

/// 블루투스 연결 실패 이벤트
final class BluetoothConnectionFailedEvent extends BluetoothConnectionEvent {
  final String _address;
  final String? error;

  const BluetoothConnectionFailedEvent(this._address, {this.error});

  @override
  String get address => _address;
}
