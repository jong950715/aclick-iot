import 'dart:async';


import 'package:bluetooth_classic/src/models/bluetooth_device.dart';
import 'package:bluetooth_classic/src/models/connection_state.dart';
import 'package:bluetooth_classic/src/models/connection_config.dart';
import 'package:bluetooth_classic/src/models/transfer_result.dart';
import 'package:bluetooth_classic/src/models/transfer_options.dart';
import 'package:bluetooth_classic/src/exceptions/bluetooth_exceptions.dart';
import 'package:bluetooth_classic/src/utils/data_utils.dart';

/// Class representing a connection to a Bluetooth device
///
/// This class handles the connection lifecycle and data transfer operations
class BluetoothConnection {
  /// Sends data to the connected Bluetooth device
  final Future<bool> Function(List<int> data) sendDataFn;

  /// The connected device
  final BluetoothDevice device;

  /// Current connection state
  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;

  /// Connection configuration
  final ConnectionConfig config;

  /// Connection statistics
  ConnectionStats _stats = ConnectionStats();

  /// Stream controller for connection state changes
  final StreamController<BluetoothConnectionState> _stateController =
      StreamController<BluetoothConnectionState>.broadcast();

  /// Stream controller for received data
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  /// Stream controller for connection statistics updates
  final StreamController<ConnectionStats> _statsController =
      StreamController<ConnectionStats>.broadcast();

  /// Timer for periodic connection statistics updates
  Timer? _connectionTimer;

  /// Stream controller for transfer progress events
  final StreamController<TransferResult> _transferController =
      StreamController<TransferResult>.broadcast();

  /// Stream of incoming data that should be linked to platform implementation
  StreamSubscription<List<int>>? _receiveSubscription;

  /// Reconnection attempts counter
  int _reconnectAttempts = 0;

  /// Timer for auto-reconnect
  Timer? _reconnectTimer;

  final Future<bool> Function() disconnectFn;

  /// Constructor
  BluetoothConnection(
    this.device, {
    this.config = const ConnectionConfig(),
    required this.sendDataFn,
    required Stream<List<int>> receiveStream,
    required this.disconnectFn,
  }) {
    // Initialize connection timestamp
    _stats = ConnectionStats(connectedAt: DateTime.now());

    // Subscribe to receive stream if provided
    _receiveSubscription = receiveStream.listen(onDataReceived);

    // 생성자에서 바로 연결됨 상태로 초기화
    // 이것이 연결 상태가 AsyncLoading에 고정되는 문제를 해결합니다
    setConnected();

    // Start connection tracking
    _startConnectionTracking();
  }

  /// Get current connection state
  BluetoothConnectionState get state => _state;

  /// Get current connection statistics
  ConnectionStats get stats => _stats;

  /// Stream of connection state changes
  Stream<BluetoothConnectionState> get stateStream => _stateController.stream;

  /// Stream of received data
  Stream<List<int>> get dataStream => _dataController.stream;

  /// Stream of connection statistics updates
  Stream<ConnectionStats> get statsStream => _statsController.stream;

  /// Stream of transfer progress events
  Stream<TransferResult> get transferStream => _transferController.stream;

  /// Check if currently connected
  bool get isConnected =>
      _state == BluetoothConnectionState.connected ||
      _state == BluetoothConnectionState.transferring;

  /// Sets the connection state and notifies listeners
  void _setState(BluetoothConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// Updates connection statistics and notifies listeners
  void _updateStats(ConnectionStats updated) {
    _stats = updated;
    _statsController.add(_stats);
  }

  /// Handle data received from device
  void onDataReceived(List<int> data) {
    // Update statistics
    _updateStats(_stats.recordBytesReceived(data.length));

    // Emit data to listeners
    _dataController.add(data);

    // Set state to transferring if not already
    if (_state == BluetoothConnectionState.connected) {
      _setState(BluetoothConnectionState.transferring);

      // Schedule return to connected state after a short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_state == BluetoothConnectionState.transferring) {
          _setState(BluetoothConnectionState.connected);
        }
      });
    }
  }

  /// Start tracking connection statistics
  void _startConnectionTracking() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateConnectionStats(),
    );
  }

  /// Periodically update connection stats (e.g., latency)
  void _updateConnectionStats() {
    // For now, just update the timestamp
    // In a real implementation, this would measure latency, etc.
    _updateStats(_stats);
  }

  /// Send data to the connected device
  ///
  /// This method sends the provided raw bytes to the connected Bluetooth device.
  /// It will automatically handle data packetization based on device buffer sizes.
  ///
  /// Example:
  /// ```dart
  /// // Send a simple byte array
  /// final success = await connection.sendData([0x01, 0x02, 0x03, 0x04]);
  /// if (success) {
  ///   print('Data sent successfully');
  /// } else {
  ///   print('Failed to send data');
  /// }
  /// ```
  ///
  /// Throws a [DeviceNotConnectedException] if the device is not connected
  /// or a [BluetoothException] if the send operation fails.
  ///
  /// Returns true if the data was sent successfully, false otherwise.
  Future<bool> sendData(List<int> data) async {
    if (!isConnected) {
      throw DeviceNotConnectedException(
          'Cannot send data: device is not connected');
    }

    try {
      _setState(BluetoothConnectionState.transferring);

      final success = await sendDataFn(data);

      if (success) {
        _updateStats(_stats.recordBytesSent(data.length));
      } else {
        _updateStats(_stats.recordError());
      }

      // Return to connected state
      _setState(BluetoothConnectionState.connected);

      return success;
    } catch (e) {
      _updateStats(_stats.recordError());
      _setState(BluetoothConnectionState.connected);
      throw BluetoothTransmissionException('Failed to send data: $e');
    }
  }

  /// Send string data to the connected device
  ///
  /// The string is encoded as UTF-8 bytes
  Future<bool> sendString(String text) async {
    final data = DataUtils.stringToBytes(text);
    return sendData(data);
  }

  /// Send data with advanced transfer options
  ///
  /// This handles packetization, checksums, and retries according to options
  Future<TransferResult> sendDataWithOptions(
    List<int> data,
    TransferOptions options,
  ) async {
    if (!isConnected) {
      throw DeviceNotConnectedException(
          'Cannot send data: device is not connected');
    }

    final stopwatch = Stopwatch()..start();
    int bytesSent = 0;

    try {
      // Encode data into packets with headers and checksums
      final packets = DataUtils.encodeDataForTransmission(data, options);

      // Send each packet with delay if specified
      for (int i = 0; i < packets.length; i++) {
        final packet = packets[i];

        // Try to send the packet (with retries if configured)
        bool packetSent = false;
        int attempts = 0;

        while (!packetSent && attempts <= options.maxRetries) {
          attempts++;

          // Send the packet
          try {
            final success = await sendDataFn(packet);

            if (success) {
              packetSent = true;
              bytesSent += packet.length;

              // Emit progress
              final progress = TransferResult(
                status: i < packets.length - 1
                    ? TransferStatus.inProgress
                    : TransferStatus.completed,
                bytesTransferred: bytesSent,
                totalBytes: data.length,
                duration: stopwatch.elapsed,
              );

              _transferController.add(progress);

              // Update stats
              _updateStats(_stats.recordBytesSent(packet.length));
            } else {
              // Failed to send packet
              _updateStats(_stats.recordError());

              if (attempts > options.maxRetries) {
                throw BluetoothTransmissionException(
                    'Failed to send packet after ${options.maxRetries} attempts');
              }
            }
          } catch (e) {
            _updateStats(_stats.recordError());

            if (attempts > options.maxRetries) {
              rethrow;
            }
          }
        }

        // Add delay between packets if specified
        if (options.packetDelayMs > 0 && i < packets.length - 1) {
          await Future.delayed(Duration(milliseconds: options.packetDelayMs));
        }
      }

      // Success
      stopwatch.stop();
      return TransferResult.success(
        bytesTransferred: bytesSent,
        totalBytes: data.length,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();

      // Create failure result
      final result = TransferResult.failure(
        errorMessage: e.toString(),
        errorCode: e is BluetoothException ? e.code : null,
        bytesTransferred: bytesSent,
        totalBytes: data.length,
        duration: stopwatch.elapsed,
      );

      _transferController.add(result);
      return result;
    }
  }

  /// Disconnect from the device
  Future<void> disconnect() async {
    if (_state == BluetoothConnectionState.disconnected ||
        _state == BluetoothConnectionState.disconnecting) {
      return;
    }

    _setState(BluetoothConnectionState.disconnecting);

    // Cancel timers
    _reconnectTimer?.cancel();
    _connectionTimer?.cancel();

    // Clean up receive subscription
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;

    _setState(BluetoothConnectionState.disconnected);
  }

  /// Set the state to connected (used by platform implementations)
  void setConnected() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _setState(BluetoothConnectionState.connected);
    _updateStats(ConnectionStats(connectedAt: DateTime.now()));
  }

  /// Set the state to disconnected (used by platform implementations)
  void setDisconnected({bool attemptReconnect = true}) {
    _setState(BluetoothConnectionState.disconnected);

    // Attempt reconnection if configured to do so
    if (attemptReconnect &&
        config.autoReconnect &&
        _reconnectAttempts < config.maxReconnectAttempts) {
      _reconnectAttempts++;

      _reconnectTimer = Timer(
        Duration(milliseconds: config.reconnectDelayMs),
        () => _attemptReconnect(),
      );
    }
  }

  /// Attempt to reconnect to the device
  void _attemptReconnect() {
    // This would be implemented by the platform-specific code
    // that creates this connection instance
  }

  /// Set the receive stream (used by platform implementations)
  void setReceiveStream(Stream<List<int>> receiveStream) {
    _receiveSubscription?.cancel();
    _receiveSubscription = receiveStream.listen(onDataReceived);
  }

  /// Dispose resources
  void dispose() {
    _reconnectTimer?.cancel();
    _connectionTimer?.cancel();
    _receiveSubscription?.cancel();

    _stateController.close();
    _dataController.close();
    _statsController.close();
    _transferController.close();
  }
}
