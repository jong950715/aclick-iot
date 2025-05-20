import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import '../encryption/encryptor.dart';

/// Command types for Bluetooth communication
enum CommandType {
  /// Initial handshake between devices
  handshake(0x01),
  
  /// Exchange WiFi credentials (SSID/Password)
  wifiCredentials(0x02),
  
  /// Request to start data transfer
  startTransfer(0x03),
  
  /// Data transfer completion signal
  transferComplete(0x04),
  
  /// Acknowledge receipt of command
  ack(0x05),
  
  /// Error response
  error(0xFF);

  final int code;
  const CommandType(this.code);
  
  factory CommandType.fromCode(int code) {
    return CommandType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => CommandType.error,
    );
  }
}

/// Status codes for protocol responses
enum StatusCode {
  success(0x00),
  invalidCommand(0x01),
  invalidPayload(0x02),
  checksumError(0x03),
  encryptionError(0x04),
  connectionError(0x05),
  timeout(0x06),
  unknown(0xFF);

  final int code;
  const StatusCode(this.code);
  
  factory StatusCode.fromCode(int code) {
    return StatusCode.values.firstWhere(
      (status) => status.code == code,
      orElse: () => StatusCode.unknown,
    );
  }
}

/// Message structure for Bluetooth communication
/// Format:
/// - Header (4 bytes): Magic number to identify the protocol
/// - Command Type (1 byte): Type of the command
/// - Payload Length (2 bytes): Length of the payload
/// - Payload (variable): Command-specific data
/// - Checksum (4 bytes): CRC32 of the command and payload
class BluetoothMessage {
  static const List<int> magicBytes = [0xAC, 0x11, 0xCC, 0xED]; // A-Click magic number
  
  final CommandType commandType;
  final Uint8List payload;
  
  BluetoothMessage({
    required this.commandType,
    required this.payload,
  });
  
  /// Creates a message from raw bytes
  factory BluetoothMessage.fromBytes(Uint8List bytes) {
    // Validate magic bytes
    for (int i = 0; i < 4; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw FormatException('Invalid message format: incorrect magic number');
      }
    }
    
    // Extract command type
    final commandCode = bytes[4];
    final commandType = CommandType.fromCode(commandCode);
    
    // Extract payload length
    final payloadLength = bytes[5] + (bytes[6] << 8);
    
    // Extract payload
    final payload = bytes.sublist(7, 7 + payloadLength);
    
    // Validate checksum
    final checksum = _calculateCrc32(bytes.sublist(4, 7 + payloadLength));
    final messageChecksum = bytes[7 + payloadLength] + 
                          (bytes[8 + payloadLength] << 8) + 
                          (bytes[9 + payloadLength] << 16) + 
                          (bytes[10 + payloadLength] << 24);
    
    if (checksum != messageChecksum) {
      throw FormatException('Checksum validation failed');
    }
    
    return BluetoothMessage(
      commandType: commandType,
      payload: payload,
    );
  }
  
  /// Converts the message to bytes for transmission
  Uint8List toBytes() {
    // Calculate total message size
    final messageSize = 11 + payload.length; // 4 (magic) + 1 (cmd) + 2 (len) + payload + 4 (crc)
    
    // Create buffer for the message
    final buffer = Uint8List(messageSize);
    
    // Add magic bytes
    for (int i = 0; i < 4; i++) {
      buffer[i] = magicBytes[i];
    }
    
    // Add command type
    buffer[4] = commandType.code;
    
    // Add payload length (16-bit little endian)
    buffer[5] = payload.length & 0xFF;
    buffer[6] = (payload.length >> 8) & 0xFF;
    
    // Add payload
    for (int i = 0; i < payload.length; i++) {
      buffer[7 + i] = payload[i];
    }
    
    // Calculate and add checksum
    final checksum = _calculateCrc32(buffer.sublist(4, 7 + payload.length));
    buffer[7 + payload.length] = checksum & 0xFF;
    buffer[8 + payload.length] = (checksum >> 8) & 0xFF;
    buffer[9 + payload.length] = (checksum >> 16) & 0xFF;
    buffer[10 + payload.length] = (checksum >> 24) & 0xFF;
    
    return buffer;
  }
  
  /// Calculate CRC32 checksum
  static int _calculateCrc32(Uint8List data) {
    int crc = 0xFFFFFFFF;
    
    for (int i = 0; i < data.length; i++) {
      crc ^= data[i];
      
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) == 1) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc = crc >> 1;
        }
      }
    }
    
    return ~crc & 0xFFFFFFFF;
  }
}

/// Handler for Bluetooth protocol communication
class BluetoothProtocol {
  final Encryptor _encryptor;
  
  BluetoothProtocol({
    required Encryptor encryptor,
  }) : _encryptor = encryptor;
  
  /// Create a handshake message
  Future<Either<String, Uint8List>> createHandshakeMessage({
    required String deviceId,
    required String deviceName,
    String? secretKey,
  }) async {
    try {
      final data = {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonData = jsonEncode(data);
      Uint8List payloadBytes;
      
      if (secretKey != null) {
        // If a secret key is provided, encrypt the data
        final encryptedResult = await _encryptor.encrypt(
          data: jsonData,
          secretKey: secretKey,
        );
        
        if (encryptedResult.isLeft()) {
          return Left(encryptedResult.getLeft().getOrElse(() => 'Encryption failed'));
        }
        
        final encryptedData = encryptedResult.getRight().getOrElse(() => '');
        payloadBytes = Uint8List.fromList(utf8.encode(encryptedData));
      } else {
        // Otherwise, use the raw data
        payloadBytes = Uint8List.fromList(utf8.encode(jsonData));
      }
      
      final message = BluetoothMessage(
        commandType: CommandType.handshake,
        payload: payloadBytes,
      );
      
      return Right(message.toBytes());
    } catch (e) {
      return Left('Failed to create handshake message: $e');
    }
  }
  
  /// Create a WiFi credentials message
  Future<Either<String, Uint8List>> createWifiCredentialsMessage({
    required String ssid,
    required String password,
    required String secretKey,
  }) async {
    try {
      final data = {
        'ssid': ssid,
        'password': password,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonData = jsonEncode(data);
      
      // Always encrypt WiFi credentials
      final encryptedResult = await _encryptor.encrypt(
        data: jsonData,
        secretKey: secretKey,
      );
      
      if (encryptedResult.isLeft()) {
        return Left(encryptedResult.getLeft().getOrElse(() => 'Encryption failed'));
      }
      
      final encryptedData = encryptedResult.getRight().getOrElse(() => '');
      final payloadBytes = Uint8List.fromList(utf8.encode(encryptedData));
      
      final message = BluetoothMessage(
        commandType: CommandType.wifiCredentials,
        payload: payloadBytes,
      );
      
      return Right(message.toBytes());
    } catch (e) {
      return Left('Failed to create WiFi credentials message: $e');
    }
  }
  
  /// Create a start transfer message
  Either<String, Uint8List> createStartTransferMessage({
    required int fileSize,
    required String fileName,
    String? transferId,
  }) {
    try {
      final data = {
        'fileSize': fileSize,
        'fileName': fileName,
        'transferId': transferId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonData = jsonEncode(data);
      final payloadBytes = Uint8List.fromList(utf8.encode(jsonData));
      
      final message = BluetoothMessage(
        commandType: CommandType.startTransfer,
        payload: payloadBytes,
      );
      
      return Right(message.toBytes());
    } catch (e) {
      return Left('Failed to create start transfer message: $e');
    }
  }
  
  /// Create an acknowledgment message
  Either<String, Uint8List> createAckMessage({
    required CommandType acknowledgedCommand,
    required StatusCode status,
    String? message,
  }) {
    try {
      final data = {
        'acknowledgedCommand': acknowledgedCommand.code,
        'status': status.code,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonData = jsonEncode(data);
      final payloadBytes = Uint8List.fromList(utf8.encode(jsonData));
      
      final bluetoothMessage = BluetoothMessage(
        commandType: CommandType.ack,
        payload: payloadBytes,
      );
      
      return Right(bluetoothMessage.toBytes());
    } catch (e) {
      return Left('Failed to create acknowledgment message: $e');
    }
  }
  
  /// Create an error message
  Either<String, Uint8List> createErrorMessage({
    required StatusCode errorCode,
    required String errorMessage,
  }) {
    try {
      final data = {
        'errorCode': errorCode.code,
        'errorMessage': errorMessage,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonData = jsonEncode(data);
      final payloadBytes = Uint8List.fromList(utf8.encode(jsonData));
      
      final message = BluetoothMessage(
        commandType: CommandType.error,
        payload: payloadBytes,
      );
      
      return Right(message.toBytes());
    } catch (e) {
      return Left('Failed to create error message: $e');
    }
  }
  
  /// Parse a received message
  Future<Either<String, Map<String, dynamic>>> parseMessage({
    required Uint8List messageBytes,
    String? secretKey,
  }) async {
    try {
      // Parse the message
      final message = BluetoothMessage.fromBytes(messageBytes);
      
      // Get the payload as a string
      final payloadString = utf8.decode(message.payload);
      
      // Check if we need to decrypt
      if (secretKey != null && 
          (message.commandType == CommandType.handshake || 
           message.commandType == CommandType.wifiCredentials)) {
        // Decrypt the payload
        final decryptedResult = await _encryptor.decrypt(
          encryptedData: payloadString,
          secretKey: secretKey,
        );
        
        if (decryptedResult.isLeft()) {
          return Left(decryptedResult.getLeft().getOrElse(() => 'Decryption failed'));
        }
        
        final decryptedData = decryptedResult.getRight().getOrElse(() => '{}');
        
        // Parse and return the decrypted data
        return Right({
          'commandType': message.commandType,
          'data': jsonDecode(decryptedData),
        });
      } else {
        // Parse and return the raw data
        return Right({
          'commandType': message.commandType,
          'data': jsonDecode(payloadString),
        });
      }
    } catch (e) {
      return Left('Failed to parse message: $e');
    }
  }
}
