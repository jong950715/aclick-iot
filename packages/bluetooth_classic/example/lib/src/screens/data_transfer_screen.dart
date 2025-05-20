import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import '../providers/bluetooth_providers.dart';

/// 블루투스 데이터 전송 화면
/// 연결된 장치와 데이터를 주고받을 수 있습니다.
class DataTransferScreen extends ConsumerStatefulWidget {
  const DataTransferScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends ConsumerState<DataTransferScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _errorMessage;
  bool _isSending = false;
  late TransferOptions _transferOptions;
  bool _useAdvancedOptions = false;
  
  // 받은 데이터 구독을 위한 StreamSubscription
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<String>? _textSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)=>_initializeConnection());

  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // 구독 취소
    _dataSubscription?.cancel();
    _textSubscription?.cancel();
    super.dispose();
  }

  /// 연결 초기화 및 데이터 수신 리스너 설정
  void _initializeConnection() {
    final connection = ref.read(bluetoothConnectionProvider);
    if (connection == null || !connection.isConnected) {
      setState(() {
        _errorMessage = '활성화된 블루투스 연결이 없습니다.';
      });
      return;
    }

    // 기본 전송 옵션 설정
    _transferOptions = TransferOptions(
      packetSize: 1024,
      useChecksum: true,
      packetDelayMs: 10,
      checksumType: ChecksumType.crc16,
      autoAcknowledge: true,
      maxRetries: 3,
    );

    // 데이터 수신 구독 설정 (텍스트 데이터)
    // ref.listen 대신 StreamSubscription 사용
    final _ = ref.read(bluetoothConnectionProvider);
    // 수신된 데이터를 문자열로 변환하여 처리
    _textSubscription = connection.dataStream
        .map((data) => String.fromCharCodes(data))
        .listen((text) {
          if (text.isNotEmpty) {
            setState(() {
              _addMessage(text, isFromMe: false);
            });
          }
        });
    }

  /// 메시지 목록에 새 메시지 추가
  void _addMessage(String text, {required bool isFromMe}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isFromMe: isFromMe,
        timestamp: DateTime.now(),
      ));
    });

    // 스크롤을 최하단으로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 텍스트 데이터 전송
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final BluetoothConnection? connection = ref.read(bluetoothConnectionProvider);
    if (connection == null || !connection.isConnected) {
      setState(() {
        _errorMessage = '활성화된 블루투스 연결이 없습니다.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      // 텍스트 전송
      // 패키지 API는 sendText가 아닌 sendString 메서드를 제공합니다
      await connection.sendString(text);
      
      // 전송한 메시지를 목록에 추가
      _addMessage(text, isFromMe: true);
      
      // 입력 필드 초기화
      _messageController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = '메시지 전송 실패: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  /// 바이너리 데이터 전송 (예제 데이터)
  Future<void> _sendBinaryData() async {
    final connection = ref.read(bluetoothConnectionProvider);
    if (connection == null || !connection.isConnected) {
      setState(() {
        _errorMessage = '활성화된 블루투스 연결이 없습니다.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      // 샘플 바이너리 데이터 생성 (0-9 숫자)
      final data = List<int>.generate(10, (i) => i);
      
      // 기본 sendData 메서드는 추가 옵션이 필요없음
      // 고급 옵션은 sendDataWithOptions 사용
      if (_useAdvancedOptions) {
        await connection.sendDataWithOptions(data, _transferOptions);
      } else {
        await connection.sendData(data);
      }

      // 로그 메시지 추가
      _addMessage('바이너리 데이터 전송: $data', isFromMe: true);
    } catch (e) {
      setState(() {
        _errorMessage = '데이터 전송 실패: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  /// 전송 옵션 설정 다이얼로그 표시
  void _showTransferOptionsDialog() {
    final currentOptions = _transferOptions;
    
    // 패키지 API와 일치하는 전송 옵션 프로퍼티 
    int packetSize = currentOptions.packetSize;
    bool useChecksum = currentOptions.useChecksum;
    int packetDelayMs = currentOptions.packetDelayMs;
    ChecksumType checksumType = currentOptions.checksumType;
    bool autoAcknowledge = currentOptions.autoAcknowledge;
    int maxRetries = currentOptions.maxRetries;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전송 옵션 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 패킷 크기 설정
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '패킷 크기 (바이트)',
                  hintText: '512',
                ),
                keyboardType: TextInputType.number,
                initialValue: packetSize.toString(),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    packetSize = int.tryParse(value) ?? packetSize;
                  }
                },
              ),
              const SizedBox(height: 8),
              
              // 체크섬 사용 여부
              SwitchListTile(
                title: const Text('체크섬 사용'),
                value: useChecksum,
                onChanged: (value) {
                  setState(() {
                    useChecksum = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              
              // 패킷 지연 시간
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '패킷 간 지연 시간 (ms)',
                  hintText: '10',
                ),
                keyboardType: TextInputType.number,
                initialValue: packetDelayMs.toString(),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    packetDelayMs = int.tryParse(value) ?? packetDelayMs;
                  }
                },
              ),
              const SizedBox(height: 8),
              
              // 자동 확인응답 설정
              SwitchListTile(
                title: const Text('자동 확인응답'),
                value: autoAcknowledge,
                onChanged: (value) {
                  setState(() {
                    autoAcknowledge = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              
              // 재시도 횟수
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '최대 재시도 횟수',
                  hintText: '3',
                ),
                keyboardType: TextInputType.number,
                initialValue: maxRetries.toString(),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    maxRetries = int.tryParse(value) ?? maxRetries;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                // 취소 시 고급 옵션 비활성화
                _useAdvancedOptions = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _transferOptions = TransferOptions(
                  packetSize: packetSize,
                  useChecksum: useChecksum,
                  packetDelayMs: packetDelayMs,
                  checksumType: checksumType,
                  autoAcknowledge: autoAcknowledge,
                  maxRetries: maxRetries,
                );
                
                // 고급 옵션 활성화
                _useAdvancedOptions = true;
              });
              Navigator.pop(context);
              _showSnackBar('전송 옵션이 업데이트되었습니다.');
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  /// 스낵바 표시
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(bluetoothConnectionProvider);
    final bluetoothConnectionState = ref.watch(bluetoothConnectionStateProvider);
    final isConnected = connection?.isConnected == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('데이터 전송'),
        actions: [
          // 전송 옵션 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '전송 옵션 설정',
            onPressed: _showTransferOptionsDialog,
          ),
          // 연결 상태 표시 아이콘
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: bluetoothConnectionState.when(
              data: (state) => Icon(
                state == BluetoothConnectionState.connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: state == BluetoothConnectionState.connected ? Colors.green : Colors.grey,
              ),
              loading: () => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Icon(Icons.error, color: Colors.red),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 연결 상태 표시줄
          Container(
            padding: const EdgeInsets.all(8.0),
            color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConnected
                        ? '연결됨: ${ref.watch(selectedDeviceProvider)?.name ?? "알 수 없는 장치"}'
                        : '연결 안됨',
                    style: TextStyle(
                      color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 오류 메시지
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
            
          // 메시지 목록
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text('메시지가 없습니다'),
                        const SizedBox(height: 8),
                        const Text(
                          '아래 입력 필드에 메시지를 작성하여 전송하세요',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageItem(message);
                    },
                  ),
          ),
          
          // 바이너리 데이터 전송 버튼
          if (isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendBinaryData,
                icon: const Icon(Icons.send),
                label: const Text('바이너리 데이터 전송 예제'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),
            
          // 메시지 입력 및 전송
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: '메시지 입력...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      enabled: isConnected,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: isConnected && !_isSending ? _sendMessage : null,
                  tooltip: '전송',
                  backgroundColor: isConnected ? Colors.blue : Colors.grey,
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 채팅 메시지 표시 위젯
  Widget _buildMessageItem(ChatMessage message) {
    final isFromMe = message.isFromMe;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              radius: 16,
              child: const Icon(
                Icons.bluetooth,
                size: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromMe ? Colors.blue.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isFromMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade500,
              radius: 16,
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 타임스탬프 포맷팅
  String _formatTimestamp(DateTime timestamp) {
    return '${_padZero(timestamp.hour)}:${_padZero(timestamp.minute)}';
  }

  /// 숫자 앞에 0 채우기
  String _padZero(int number) {
    return number.toString().padLeft(2, '0');
  }
}

/// 채팅 메시지 모델 클래스
class ChatMessage {
  final String text;
  final bool isFromMe;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isFromMe,
    required this.timestamp,
  });
}
