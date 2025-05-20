import 'dart:convert';
import '../models/transfer_options.dart';

/// Utility class for data conversion, validation, and manipulation
/// for Bluetooth communications
class DataUtils {
  /// Converts a string to a list of bytes using UTF-8 encoding
  static List<int> stringToBytes(String data) {
    return utf8.encode(data);
  }
  
  /// Converts a list of bytes to a string using UTF-8 encoding
  /// If the data is not valid UTF-8, returns an empty string
  static String bytesToString(List<int> data) {
    try {
      return utf8.decode(data);
    } catch (e) {
      return '';
    }
  }
  
  /// Splits data into packets of the specified size
  static List<List<int>> splitIntoPackets(List<int> data, int packetSize) {
    final result = <List<int>>[];
    for (var i = 0; i < data.length; i += packetSize) {
      final end = (i + packetSize < data.length) ? i + packetSize : data.length;
      result.add(data.sublist(i, end));
    }
    return result;
  }
  
  /// Calculates checksum for a packet based on the specified checksum type
  static int calculateChecksum(List<int> data, ChecksumType type) {
    switch (type) {
      case ChecksumType.xor8:
        return _calculateXor8Checksum(data);
      case ChecksumType.crc16:
        return _calculateCrc16Checksum(data);
      case ChecksumType.crc32:
        return _calculateCrc32Checksum(data);
      case ChecksumType.md5:
        return _calculateMd5Checksum(data);
    }
  }
  
  /// Calculates a simple XOR-8 checksum
  static int _calculateXor8Checksum(List<int> data) {
    int checksum = 0;
    for (final byte in data) {
      checksum ^= byte;
    }
    return checksum;
  }
  
  /// Calculates a CRC-16 checksum using the CCITT algorithm
  static int _calculateCrc16Checksum(List<int> data) {
    // CRC-16-CCITT polynomial: x^16 + x^12 + x^5 + 1 (0x1021)
    const polynomial = 0x1021;
    int crc = 0xFFFF; // Initial value
    
    for (final byte in data) {
      crc ^= (byte << 8) & 0xFFFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) & 0xFFFF) ^ polynomial;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    
    return crc;
  }
  
  /// Calculates a CRC-32 checksum
  static int _calculateCrc32Checksum(List<int> data) {
    // CRC-32 polynomial: 0x04C11DB7
    // Initialize CRC table if needed
    _initCrc32Table();
    
    int crc = 0xFFFFFFFF; // Initial value
    
    for (final byte in data) {
      final index = ((crc ^ byte) & 0xFF);
      crc = ((crc >> 8) & 0xFFFFFFFF) ^ _crc32Table[index];
    }
    
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF; // Final XOR value
  }
  
  /// CRC-32 lookup table
  static List<int> _crc32Table = [];
  
  /// Initialize the CRC-32 table
  static void _initCrc32Table() {
    if (_crc32Table != null) return;
    
    _crc32Table = List<int>.filled(256, 0);
    const polynomial = 0xEDB88320;
    
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) == 1) {
          crc = (crc >> 1) ^ polynomial;
        } else {
          crc = crc >> 1;
        }
      }
      _crc32Table![i] = crc;
    }
  }
  
  /// Calculate MD5 hash and return it as an integer
  /// Note: This is a simplified implementation, in real use
  /// you'd return the full MD5 hash
  static int _calculateMd5Checksum(List<int> data) {
    final digest = md5.convert(data);
    // digest.bytes 대신 digest를 직접 사용
    final bytes = digest.toString().substring(0, 8);
    // 16진수 문자열을 정수로 변환
    return int.parse(bytes, radix: 16);
  }
  
  /// Add a checksum to the end of a packet
  static List<int> addChecksum(List<int> packet, ChecksumType type) {
    final checksum = calculateChecksum(packet, type);
    
    // Convert checksum to bytes
    final checksumBytes = <int>[];
    switch (type) {
      case ChecksumType.xor8:
        checksumBytes.add(checksum);
        break;
      case ChecksumType.crc16:
        checksumBytes.addAll([
          (checksum >> 8) & 0xFF,
          checksum & 0xFF,
        ]);
        break;
      case ChecksumType.crc32:
      case ChecksumType.md5:
        checksumBytes.addAll([
          (checksum >> 24) & 0xFF,
          (checksum >> 16) & 0xFF,
          (checksum >> 8) & 0xFF,
          checksum & 0xFF,
        ]);
        break;
    }
    
    // Return packet with checksum appended
    return [...packet, ...checksumBytes];
  }
  
  /// Verify the checksum of a packet
  static bool verifyChecksum(List<int> packet, ChecksumType type) {
    if (packet.isEmpty) return false;
    
    int checksumSize;
    switch (type) {
      case ChecksumType.xor8:
        checksumSize = 1;
        break;
      case ChecksumType.crc16:
        checksumSize = 2;
        break;
      case ChecksumType.crc32:
      case ChecksumType.md5:
        checksumSize = 4;
        break;
    }
    
    if (packet.length <= checksumSize) return false;
    
    final data = packet.sublist(0, packet.length - checksumSize);
    final expectedChecksumBytes = packet.sublist(packet.length - checksumSize);
    final calculatedChecksum = calculateChecksum(data, type);
    
    int expectedChecksum;
    switch (type) {
      case ChecksumType.xor8:
        expectedChecksum = expectedChecksumBytes[0];
        break;
      case ChecksumType.crc16:
        expectedChecksum = (expectedChecksumBytes[0] << 8) | expectedChecksumBytes[1];
        break;
      case ChecksumType.crc32:
      case ChecksumType.md5:
        expectedChecksum = (expectedChecksumBytes[0] << 24) | 
                           (expectedChecksumBytes[1] << 16) |
                           (expectedChecksumBytes[2] << 8) |
                            expectedChecksumBytes[3];
        break;
    }
    
    return calculatedChecksum == expectedChecksum;
  }
  
  /// Encodes data with packet headers, checksums, and packet numbers
  /// Returns a list of packets ready for transmission
  static List<List<int>> encodeDataForTransmission(
    List<int> data,
    TransferOptions options,
  ) {
    // Split data into packets of the specified size
    final packets = splitIntoPackets(data, options.packetSize);
    final result = <List<int>>[];
    
    // Add header and checksum to each packet
    for (int i = 0; i < packets.length; i++) {
      final packet = packets[i];
      
      // Create header: Start byte (0x02), packet number, total packets
      final header = <int>[
        0x02, // STX (Start of Text)
        i, // Packet number
        packets.length, // Total number of packets
        packet.length, // Size of this packet
      ];
      
      // Combine header and data
      final combinedPacket = [...header, ...packet];
      
      // Add checksum if enabled
      final finalPacket = options.useChecksum
          ? addChecksum(combinedPacket, options.checksumType)
          : combinedPacket;
      
      // Add end byte
      final completePacket = [...finalPacket, 0x03]; // ETX (End of Text)
      result.add(completePacket);
    }
    
    return result;
  }
  
  /// Decodes a received packet, verifying checksums if applicable
  /// Returns the payload data if valid, or null if invalid
  static List<int>? decodeReceivedPacket(
    List<int> packet,
    TransferOptions options,
  ) {
    // Check minimum packet size: STX + packet# + total + size + ETX
    if (packet.length < 5) return null;
    
    // Check start and end bytes
    if (packet.first != 0x02 || packet.last != 0x03) return null;
    
    // Remove STX and ETX bytes
    final strippedPacket = packet.sublist(1, packet.length - 1);
    
    // Verify checksum if needed
    if (options.useChecksum) {
      if (!verifyChecksum(strippedPacket, options.checksumType)) {
        return null;
      }
      
      int checksumSize;
      switch (options.checksumType) {
        case ChecksumType.xor8:
          checksumSize = 1;
          break;
        case ChecksumType.crc16:
          checksumSize = 2;
          break;
        case ChecksumType.crc32:
        case ChecksumType.md5:
          checksumSize = 4;
          break;
      }
      
      // Remove checksum bytes
      final dataWithHeader = strippedPacket.sublist(0, strippedPacket.length - checksumSize);
      
      // Extract header and payload
      if (dataWithHeader.length < 4) return null;
      
      // First 4 bytes are header: packet#, total packets, payload size
      final payloadSize = dataWithHeader[3];
      
      // Extract payload
      if (dataWithHeader.length < 4 + payloadSize) return null;
      return dataWithHeader.sublist(4, 4 + payloadSize);
    } else {
      // No checksum verification needed
      if (strippedPacket.length < 4) return null;
      
      final payloadSize = strippedPacket[3];
      if (strippedPacket.length < 4 + payloadSize) return null;
      return strippedPacket.sublist(4, 4 + payloadSize);
    }
  }
}

/// MD5 implementation for checksum calculation
/// Note: This is a simplified implementation for the example
/// In production, you'd use a proper crypto library
class _Md5 {
  final List<int> _hash;
  
  _Md5() : _hash = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476];
  
  List<int> get bytes {
    final result = <int>[];
    for (final h in _hash) {
      result.addAll([
        h & 0xFF,
        (h >> 8) & 0xFF,
        (h >> 16) & 0xFF,
        (h >> 24) & 0xFF,
      ]);
    }
    return result;
  }
  
  // Simplified convert method - in real implementation this would actually calculate MD5
  List<int> convert(List<int> data) {
    // This is just a placeholder - real MD5 would do proper calculation
    return bytes;
  }
}

/// Simplified MD5 implementation (just for the example)
/// In a real application, use a proper crypto library
final md5 = _Md5();
