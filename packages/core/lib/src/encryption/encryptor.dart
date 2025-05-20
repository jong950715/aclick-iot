import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:fpdart/fpdart.dart';

/// Provides encryption utilities for securing IoT communication
class Encryptor {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypts data using AES-GCM with the provided key
  Future<Either<String, String>> encrypt({
    required String data,
    required String secretKey,
  }) async {
    try {
      // Convert the secret key to a SecretKey
      final key = SecretKey(base64Decode(secretKey));
      
      // Generate a random nonce
      final nonce = _algorithm.newNonce();
      
      // Encrypt the data
      final secretBox = await _algorithm.encrypt(
        utf8.encode(data),
        secretKey: key,
        nonce: nonce,
      );
      
      // Combine nonce and cipherText to create the encrypted data
      final combined = Uint8List(nonce.length + secretBox.cipherText.length);
      combined.setRange(0, nonce.length, nonce);
      combined.setRange(nonce.length, combined.length, secretBox.cipherText);
      
      return Right(base64Encode(combined));
    } catch (e) {
      return Left('Encryption failed: $e');
    }
  }

  /// Decrypts data using AES-GCM with the provided key
  Future<Either<String, String>> decrypt({
    required String encryptedData,
    required String secretKey,
  }) async {
    try {
      // Decode the base64 encrypted data
      final decoded = base64Decode(encryptedData);
      
      // Split nonce and cipherText
      final nonce = decoded.sublist(0, _algorithm.nonceLength);
      final cipherText = decoded.sublist(_algorithm.nonceLength);
      
      // Convert the secret key
      final key = SecretKey(base64Decode(secretKey));
      
      // Decrypt the data
      final plainText = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac.empty),
        secretKey: key,
      );
      
      return Right(utf8.decode(plainText));
    } catch (e) {
      return Left('Decryption failed: $e');
    }
  }

  /// Generates a new random secret key
  Future<String> generateSecretKey() async {
    final key = await _algorithm.newSecretKey();
    final keyBytes = await key.extractBytes();
    return base64Encode(keyBytes);
  }
}
