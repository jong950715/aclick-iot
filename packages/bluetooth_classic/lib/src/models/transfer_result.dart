/// 데이터 전송 상태를 나타내는 열거형
enum TransferStatus {
  /// 전송 진행 중
  inProgress,
  
  /// 전송 완료됨
  completed,
  
  /// 전송 실패함
  failed,
  
  /// 전송 취소됨
  cancelled,
}

/// 데이터 전송 결과를 나타내는 클래스
class TransferResult {
  /// 전송 상태
  final TransferStatus status;
  
  /// 전송된 바이트 수
  final int bytesTransferred;
  
  /// 전송할 총 바이트 수
  final int? totalBytes;
  
  /// 오류 메시지 (실패 시)
  final String? errorMessage;
  
  /// 오류 코드 (실패 시)
  final String? errorCode;
  
  /// 전송 소요 시간
  final Duration duration;
  
  /// 전송 성공 여부
  bool get isSuccess => status == TransferStatus.completed;
  
  /// 진행률 (0-100)
  double get progressPercentage {
    if (totalBytes == null || totalBytes == 0) return 0.0;
    return (bytesTransferred / totalBytes!) * 100.0;
  }
  
  /// 생성자
  const TransferResult({
    required this.status,
    required this.bytesTransferred,
    this.totalBytes,
    this.errorMessage,
    this.errorCode,
    required this.duration,
  });
  
  /// 성공한 전송 결과 생성
  factory TransferResult.success({
    required int bytesTransferred,
    int? totalBytes,
    required Duration duration,
  }) {
    return TransferResult(
      status: TransferStatus.completed,
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
      duration: duration,
    );
  }
  
  /// 실패한 전송 결과 생성
  factory TransferResult.failure({
    required String errorMessage,
    String? errorCode,
    required int bytesTransferred,
    int? totalBytes,
    required Duration duration,
  }) {
    return TransferResult(
      status: TransferStatus.failed,
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
      errorMessage: errorMessage,
      errorCode: errorCode,
      duration: duration,
    );
  }
  
  /// 취소된 전송 결과 생성
  factory TransferResult.cancelled({
    required int bytesTransferred,
    int? totalBytes,
    required Duration duration,
  }) {
    return TransferResult(
      status: TransferStatus.cancelled,
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
      duration: duration,
    );
  }
  
  @override
  String toString() {
    switch (status) {
      case TransferStatus.completed:
        return 'TransferResult: Success - $bytesTransferred/${totalBytes ?? 'unknown'} bytes in ${duration.inMilliseconds}ms';
      case TransferStatus.failed:
        return 'TransferResult: Failed - $errorMessage';
      case TransferStatus.cancelled:
        return 'TransferResult: Cancelled - $bytesTransferred/${totalBytes ?? 'unknown'} bytes transferred';
      case TransferStatus.inProgress:
        return 'TransferResult: In Progress - $bytesTransferred/${totalBytes ?? 'unknown'} bytes (${progressPercentage.toStringAsFixed(1)}%)';
    }
  }
}
