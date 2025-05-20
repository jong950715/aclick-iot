import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rxdart/rxdart.dart';

import '../encryption/encryptor.dart';
import 'bluetooth_protocol.dart';

/// Handler for managing Bluetooth communication using the defined protocol
class BluetoothProtocolHandler {
  final BluetoothProtocol _protocol;
  final Encryptor _encryptor;

  /// Stream controller for incoming messages
  final _messageStreamController =
      BehaviorSubject<Either<String, Map<String, dynamic>>>();

  /// Stream subscription for data reception
  StreamSubscription<List<int>>? _dataSubscription;

  /// Current receive buffer for assembling messages
  final List<int> _receiveBuffer = [];

  /// Session key for secure communication
  String? _sessionKey;

  /// Callback function for sending raw data
  final Future<Either<String, bool>> Function(Uint8List data)? _sendCallback;

  BluetoothProtocolHandler({
    required BluetoothProtocol protocol,
    required Encryptor encryptor,
    required Future<Either<String, bool>> Function(Uint8List data) sendCallback,
    required Stream<List<int>> dataStream,
    String? initialSessionKey,
  })  : _protocol = protocol,
        _encryptor = encryptor,
        _sessionKey = initialSessionKey,
        _sendCallback = sendCallback {
    listenToData(dataStream);
    generateSessionKey();
  }

  factory BluetoothProtocolHandler.fromConnectionStream(
      BehaviorSubject<BluetoothConnection?> connectionStream) {
    final encryptor = Encryptor();
    final protocol = BluetoothProtocol(encryptor: encryptor);
    final rxDataStream = connectionStream.switchMap(
      (connection) => connection?.dataStream ?? Stream<List<int>>.empty(),
    );
    return BluetoothProtocolHandler(
      protocol: protocol,
      encryptor: encryptor,
      sendCallback: (Uint8List data) async {
        final success = await connectionStream.value?.sendDataFn(data) ?? false;
        if (!success) {
          return Left('Failed to send data');
        }
        return Right(true);
      },
      dataStream: rxDataStream,
    );
  }

  /// Stream of processed messages
  Stream<Either<String, Map<String, dynamic>>> get messageStream =>
      _messageStreamController.stream;

  /// Set a new session key for encryption
  void setSessionKey(String key) {
    _sessionKey = key;
  }

  /// Start listening to incoming data
  void listenToData(Stream<List<int>> dataStream) {
    // Cancel any existing subscription
    _dataSubscription?.cancel();

    // Clear the buffer
    _receiveBuffer.clear();

    // Subscribe to new data
    _dataSubscription = dataStream.listen(
      _processIncomingData,
      onError: (error) {
        _messageStreamController.add(Left('Data reception error: $error'));
      },
      onDone: () {
        _messageStreamController.add(Left('Data stream closed'));
      },
    );
  }

  /// Process incoming data chunks and extract messages
  void _processIncomingData(List<int> data) {
    // Add data to the buffer
    _receiveBuffer.addAll(data);

    // Process complete messages
    _processBuffer();
  }

  /// Process the buffer and extract complete messages
  void _processBuffer() {
    // Continue processing while we have enough data for a potential message
    while (_receiveBuffer.length >= 11) {
      // Minimum message size (header + command + length + min checksum)
      // Check for magic bytes
      if (_receiveBuffer[0] != BluetoothMessage.magicBytes[0] ||
          _receiveBuffer[1] != BluetoothMessage.magicBytes[1] ||
          _receiveBuffer[2] != BluetoothMessage.magicBytes[2] ||
          _receiveBuffer[3] != BluetoothMessage.magicBytes[3]) {
        // Invalid start, remove the first byte and continue
        _receiveBuffer.removeAt(0);
        continue;
      }

      // Extract payload length
      final payloadLength = _receiveBuffer[5] + (_receiveBuffer[6] << 8);

      // Calculate total message size
      final messageSize = 11 +
          payloadLength; // 4 (magic) + 1 (cmd) + 2 (len) + payload + 4 (crc)

      // Check if we have a complete message
      if (_receiveBuffer.length < messageSize) {
        // Not enough data yet, wait for more
        break;
      }

      // Extract the complete message
      final messageBytes =
          Uint8List.fromList(_receiveBuffer.sublist(0, messageSize));

      // Remove the processed message from the buffer
      _receiveBuffer.removeRange(0, messageSize);

      // Process the message asynchronously
      _processMessage(messageBytes);
    }
  }

  /// Process a complete message
  Future<void> _processMessage(Uint8List messageBytes) async {
    try {
      // Parse the message
      final Either<String, Map<String, dynamic>> parsedMessage =
          await _protocol.parseMessage(
        messageBytes: messageBytes,
        secretKey: _sessionKey,
      );

      // Add the parsed message to the stream
      _messageStreamController.add(parsedMessage);

      // Automatically send ACK for certain command types
      if (parsedMessage.isRight()) {
        final data = parsedMessage.getRight().getOrElse(() => {});
        final commandType = data['commandType'] as CommandType?;

        if (commandType != null &&
            commandType != CommandType.ack &&
            commandType != CommandType.error) {
          // Auto-acknowledge message receipt
          await sendAck(
            acknowledgedCommand: commandType,
            status: StatusCode.success,
          );
        }
      }
    } catch (e) {
      // Report error
      _messageStreamController.add(Left('Error processing message: $e'));
    }
  }

  /// -------------------- Send --------------------///
  /// Send a handshake message
  Future<Either<String, bool>> sendHandshake({
    required String deviceId,
    required String deviceName,
  }) async {
    final messageResult = await _protocol.createHandshakeMessage(
      deviceId: deviceId,
      deviceName: deviceName,
      secretKey: _sessionKey,
    );

    if (messageResult.isLeft()) {
      return Left(messageResult
          .getLeft()
          .getOrElse(() => 'Failed to create handshake message'));
    }

    return _sendData(messageResult.getRight().getOrElse(() => Uint8List(0)));
  }

  /// Send WiFi credentials
  Future<Either<String, bool>> sendWifiCredentials({
    required String ssid,
    required String password,
  }) async {
    if (_sessionKey == null) {
      return Left('No session key available for secure transmission');
    }

    final messageResult = await _protocol.createWifiCredentialsMessage(
      ssid: ssid,
      password: password,
      secretKey: _sessionKey!,
    );

    if (messageResult.isLeft()) {
      return Left(messageResult
          .getLeft()
          .getOrElse(() => 'Failed to create WiFi credentials message'));
    }

    return _sendData(messageResult.getRight().getOrElse(() => Uint8List(0)));
  }

  /// Initiate a data transfer
  Future<Either<String, bool>> sendStartTransfer({
    required int fileSize,
    required String fileName,
    String? transferId,
  }) async {
    final messageResult = _protocol.createStartTransferMessage(
      fileSize: fileSize,
      fileName: fileName,
      transferId: transferId,
    );

    if (messageResult.isLeft()) {
      return Left(messageResult
          .getLeft()
          .getOrElse(() => 'Failed to create start transfer message'));
    }

    return _sendData(messageResult.getRight().getOrElse(() => Uint8List(0)));
  }

  /// Send transfer complete notification
  Future<Either<String, bool>> sendTransferComplete({
    required String transferId,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      final data = {
        'transferId': transferId,
        'success': success,
        'errorMessage': errorMessage,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonData = jsonEncode(data);
      final payloadBytes = Uint8List.fromList(utf8.encode(jsonData));

      final message = BluetoothMessage(
        commandType: CommandType.transferComplete,
        payload: payloadBytes,
      );

      return _sendData(message.toBytes());
    } catch (e) {
      return Left('Failed to create transfer complete message: $e');
    }
  }

  /// Send acknowledgment for a received message
  Future<Either<String, bool>> sendAck({
    required CommandType acknowledgedCommand,
    required StatusCode status,
    String? message,
  }) async {
    final messageResult = _protocol.createAckMessage(
      acknowledgedCommand: acknowledgedCommand,
      status: status,
      message: message,
    );

    if (messageResult.isLeft()) {
      return Left(messageResult
          .getLeft()
          .getOrElse(() => 'Failed to create acknowledgment message'));
    }

    return _sendData(messageResult.getRight().getOrElse(() => Uint8List(0)));
  }

  /// Send an error message
  Future<Either<String, bool>> sendError({
    required StatusCode errorCode,
    required String errorMessage,
  }) async {
    final messageResult = _protocol.createErrorMessage(
      errorCode: errorCode,
      errorMessage: errorMessage,
    );

    if (messageResult.isLeft()) {
      return Left(messageResult
          .getLeft()
          .getOrElse(() => 'Failed to create error message'));
    }

    return _sendData(messageResult.getRight().getOrElse(() => Uint8List(0)));
  }

  /// Send raw data using the provided callback
  Future<Either<String, bool>> _sendData(Uint8List data) async {
    if (_sendCallback == null) {
      return Left('No send callback provided');
    }

    return _sendCallback(data);
  }
  /// -------------------- Send --------------------///


    /// Generate a new session key
  Future<Either<String, String>> generateSessionKey() async {
    try {
      // Generate a random 256-bit key (32 bytes)
      final key = await _encryptor.generateSecretKey();
      //
      // if (key.isLeft()) {
      //   return Left(
      //       key.getLeft().getOrElse(() => 'Failed to generate session key'));
      // }
      //
      // final sessionKey = key.getRight().getOrElse(() => '');
      _sessionKey = key;

      return Right(key);
    } catch (e) {
      return Left('Failed to generate session key: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _dataSubscription?.cancel();
    _messageStreamController.close();
  }
}
