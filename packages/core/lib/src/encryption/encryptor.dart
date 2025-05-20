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
      
      // JSON으로 직렬화하여 nonce, cipherText, mac 저장
      final encryptionData = {
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      };
      
      // JSON 인코딩 후 base64로 반환
      return Right(base64Encode(utf8.encode(jsonEncode(encryptionData))));
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
      // JSON 형식 복원
      final jsonData = utf8.decode(base64Decode(encryptedData));
      final Map<String, dynamic> encryptionData = jsonDecode(jsonData);
      
      // 각 컴포넌트 추출
      final nonce = base64Decode(encryptionData['nonce']);
      final cipherText = base64Decode(encryptionData['cipherText']);
      final macBytes = base64Decode(encryptionData['mac']);
      
      // Convert the secret key
      final key = SecretKey(base64Decode(secretKey));
      
      // Decrypt the data
      final plainText = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );
      
      return Right(utf8.decode(plainText));
    } catch (e) {
      return Left('Decryption failed: $e');
    }
  }

  /// Generates a new random secret key
  Future<Either<String, String>> generateRandomKey(int keyLengthBytes) async {
    try {
      final key = await _algorithm.newSecretKey();
      final keyBytes = await key.extractBytes();
      return Right(base64Encode(keyBytes));
    } catch (e) {
      return Left('Failed to generate key: $e');
    }
  }
  
  /// 키를 생성하고 바로 반환 (편의 메서드)
  Future<String> generateSecretKey() async {
    final result = await generateRandomKey(32);
    return result.getRight().getOrElse(() => '');
  }
}
