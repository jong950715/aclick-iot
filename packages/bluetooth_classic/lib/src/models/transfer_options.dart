import 'transfer_result.dart';

/// Represents options for data transfer operations
class TransferOptions {
  /// Maximum size of individual data packets in bytes
  final int packetSize;
  
  /// Whether to use checksums for data integrity verification
  final bool useChecksum;
  
  /// Milliseconds to wait between sending packets
  final int packetDelayMs;
  
  /// Type of checksum to use for data integrity
  final ChecksumType checksumType;
  
  /// Whether to handle packet acknowledgment automatically
  final bool autoAcknowledge;
  
  /// Number of retry attempts for failed packet transmissions
  final int maxRetries;
  
  /// Default constructor with reasonable defaults for most scenarios
  const TransferOptions({
    this.packetSize = 512,           // 512 bytes per packet by default
    this.useChecksum = true,         // Enable checksum by default
    this.packetDelayMs = 10,         // Small delay between packets
    this.checksumType = ChecksumType.crc16, // CRC-16 is a good balance
    this.autoAcknowledge = true,     // Auto-acknowledge packets by default
    this.maxRetries = 3,             // Retry up to 3 times
  });
  
  /// Creates a high-throughput configuration optimized for speed
  /// with minimal verification and no delays
  factory TransferOptions.highThroughput() {
    return const TransferOptions(
      packetSize: 1024,              // Larger packets
      useChecksum: false,            // No checksums for speed
      packetDelayMs: 0,              // No delay between packets
      autoAcknowledge: false,        // No auto-acknowledgment
      maxRetries: 0,                 // No retries
    );
  }
  
  /// Creates a high-reliability configuration that prioritizes
  /// data integrity over speed
  factory TransferOptions.highReliability() {
    return const TransferOptions(
      packetSize: 256,               // Smaller packets for better reliability
      useChecksum: true,             // Use checksums
      checksumType: ChecksumType.crc32, // Stronger checksum
      packetDelayMs: 20,             // Increased delay between packets
      autoAcknowledge: true,         // Wait for acknowledgment
      maxRetries: 5,                 // More retries
    );
  }
  
  /// Creates a balanced configuration suitable for most applications
  factory TransferOptions.balanced() {
    return const TransferOptions();  // Use default values
  }
  
  /// Creates a copy with updated properties
  TransferOptions copyWith({
    int? packetSize,
    bool? useChecksum,
    int? packetDelayMs,
    ChecksumType? checksumType,
    bool? autoAcknowledge,
    int? maxRetries,
  }) {
    return TransferOptions(
      packetSize: packetSize ?? this.packetSize,
      useChecksum: useChecksum ?? this.useChecksum,
      packetDelayMs: packetDelayMs ?? this.packetDelayMs,
      checksumType: checksumType ?? this.checksumType,
      autoAcknowledge: autoAcknowledge ?? this.autoAcknowledge,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }
}

/// Types of checksums available for data integrity verification
enum ChecksumType {
  /// Simple 8-bit checksum (XOR of all bytes)
  /// Fast but weak integrity protection
  xor8,
  
  /// 16-bit CRC (Cyclic Redundancy Check)
  /// Good balance of speed and reliability
  crc16,
  
  /// 32-bit CRC
  /// Stronger integrity protection but more processing overhead
  crc32,
  
  /// Message Digest 5 - cryptographic hash
  /// Strong integrity verification but significant overhead
  md5,
}

/// Direction of data transfer
enum TransferDirection {
  /// Data is being sent from the local device to the remote device
  send,
  
  /// Data is being received from the remote device to the local device
  receive,
  
  /// Data is being sent in both directions simultaneously
  bidirectional,
}

