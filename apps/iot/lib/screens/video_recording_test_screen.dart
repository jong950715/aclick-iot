import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/services/event_clip_handler.dart';
import 'package:iot/utils/file_path_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/video_recording_service.dart';
import 'dart:io';
import 'package:riverpod/riverpod.dart';

class VideoRecordingTestScreen extends ConsumerStatefulWidget {
  const VideoRecordingTestScreen({Key? key}) : super(key: key);

  @override
  _VideoRecordingTestScreenState createState() => _VideoRecordingTestScreenState();
}

class _VideoRecordingTestScreenState
    extends ConsumerState<VideoRecordingTestScreen> {
  final VideoRecordingService _videoService = VideoRecordingService();
  bool _isRecording = false;
  String _statusMessage = '';
  Map<String, dynamic> _storageStatus = {};
  String? _lastClipPath;

  // 설정 관련 상태
  final TextEditingController _segmentSecondsController = TextEditingController(text: '10');
  final TextEditingController _gopSecondsController = TextEditingController(text: '1');
  final TextEditingController _fsyncIntervalController = TextEditingController(text: '2000');
  final TextEditingController _maxStorageMBController = TextEditingController(text: '1024');  // 1GB
  
  @override
  void initState() {
    super.initState();
    _updateStorageStatus();
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        _requestPermissions();
      },
    );
  }
  
  @override
  void dispose() {
    // 녹화 중인 경우 중지
    if (_isRecording) {
      _videoService.stopRecording();
    }
    
    _segmentSecondsController.dispose();
    _gopSecondsController.dispose();
    _fsyncIntervalController.dispose();
    _maxStorageMBController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // 필요한 권한 목록
    final permissions = [
      Permission.camera,
      Permission.microphone,
      Permission.manageExternalStorage,
    ];

    // 권한 상태 확인
    Map<Permission, PermissionStatus> statuses = await permissions.request();
  }

  // 녹화 시작
  Future<void> _startRecording() async {
    try {
      // 설정 적용
      final config = VideoRecorderConfig(
        outputDir: await FilePathUtils.getVideoDirectoryPath(),
        segmentSeconds: int.tryParse(_segmentSecondsController.text) ?? 10,
        gopSeconds: int.tryParse(_gopSecondsController.text) ?? 1,
        fsyncIntervalMs: int.tryParse(_fsyncIntervalController.text) ?? 2000,
        maxStorageMB: int.tryParse(_maxStorageMBController.text) ?? 1024,
        width: 1280,
        height: 720,
        bitrate: 4000000,  // 4Mbps
        fps: 30,
      );
      
      final success = await _videoService.startRecording(config: config);
      
      setState(() {
        _isRecording = success;
        _statusMessage = success ? '녹화 시작됨' : '녹화 시작 실패';
      });
      
      // 녹화 시작 후 저장 공간 정보 업데이트
      await _updateStorageStatus();
      
    } catch (e) {
      setState(() {
        _statusMessage = '오류: $e';
      });
    }
  }
  
  // 녹화 중지
  Future<void> _stopRecording() async {
    try {
      final success = await _videoService.stopRecording();
      
      setState(() {
        _isRecording = !success;
        _statusMessage = success ? '녹화 중지됨' : '녹화 중지 실패';
      });
      
      // 녹화 중지 후 저장 공간 정보 업데이트
      await _updateStorageStatus();
      
    } catch (e) {
      setState(() {
        _statusMessage = '오류: $e';
      });
    }
  }
  
  // 이벤트 클립을 갤러리에 저장
  Future<void> _saveClipToGallery() async {
    if (_lastClipPath == null) {
      setState(() {
        _statusMessage = '저장할 클립이 없습니다';
      });
      return;
    }
    
    try {
      // 갤러리 경로 (안드로이드)
      final galleryDir = '/storage/emulated/0/DCIM/Camera';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = await _videoService.copyEventClipToDirectory(
        _lastClipPath!, 
        galleryDir,
        newName: 'event_clip_$timestamp.mp4'
      );
      
      setState(() {
        _statusMessage = newPath != null
            ? '클립을 갤러리에 저장함: $newPath'
            : '갤러리에 저장 실패';
      });
      
    } catch (e) {
      setState(() {
        _statusMessage = '오류: $e';
      });
    }
  }
  
  // 저장 공간 상태 업데이트
  Future<void> _updateStorageStatus() async {
    try {
      final status = await _videoService.getStorageStatus();
      setState(() {
        _storageStatus = status;
      });
    } catch (e) {
      print('저장 공간 상태 업데이트 오류: $e');
    }
  }
  
  // 설정 적용하기
  Future<void> _applyConfiguration() async {
    try {
      final config = VideoRecorderConfig(
        outputDir: 'test_recordings',
        segmentSeconds: int.tryParse(_segmentSecondsController.text) ?? 10,
        gopSeconds: int.tryParse(_gopSecondsController.text) ?? 1,
        fsyncIntervalMs: int.tryParse(_fsyncIntervalController.text) ?? 2000,
        maxStorageMB: int.tryParse(_maxStorageMBController.text) ?? 1024,
      );
      
      final success = await _videoService.configure(config);
      
      setState(() {
        _statusMessage = success ? '설정 적용됨' : '설정 적용 실패';
      });
      
    } catch (e) {
      setState(() {
        _statusMessage = '오류: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(eventClipHandlerProvider).jobs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('비디오 녹화 테스트'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상태: ${_isRecording ? "녹화 중" : "대기 중"}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('메시지: $_statusMessage'),
                    const SizedBox(height: 8),
                    Text('마지막 클립: ${_lastClipPath ?? "없음"}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 저장 공간 정보 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '저장 공간 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('세그먼트 크기: ${_storageStatus["totalSegmentSizeMB"] ?? 0}MB'),
                    Text('세그먼트 수: ${_storageStatus["segmentCount"] ?? 0}개'),
                    Text('가용 공간: ${_storageStatus["availableSpaceMB"] ?? 0}MB'),
                    Text('최대 저장: ${_storageStatus["maxStorageSizeMB"] ?? 0}MB'),
                    if (_storageStatus["resolution"] != null)
                      Text('해상도: ${_storageStatus["resolution"]}'),
                    if (_storageStatus["segmentDurationSeconds"] != null)
                      Text('세그먼트 길이: ${_storageStatus["segmentDurationSeconds"]}초'),
                    if (_storageStatus["gopDurationSeconds"] != null)
                      Text('GOP 길이: ${_storageStatus["gopDurationSeconds"]}초'),
                    if (_storageStatus["fsyncIntervalMs"] != null)
                      Text('fsync 간격: ${_storageStatus["fsyncIntervalMs"]}ms'),
                    if (_storageStatus["outputDirectory"] != null)
                      Text('저장 경로: ${_storageStatus["outputDirectory"]}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 설정 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '녹화 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _segmentSecondsController,
                      decoration: const InputDecoration(
                        labelText: '세그먼트 길이 (초)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _gopSecondsController,
                      decoration: const InputDecoration(
                        labelText: 'GOP 길이 (초)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fsyncIntervalController,
                      decoration: const InputDecoration(
                        labelText: 'fsync 간격 (밀리초)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _maxStorageMBController,
                      decoration: const InputDecoration(
                        labelText: '최대 저장 공간 (MB)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyConfiguration,
                        child: const Text('설정 적용'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 녹화 제어 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? null : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('녹화 시작'),
                ),
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('녹화 중지'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 이벤트 클립 제어 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? ref.watch(eventClipHandlerProvider).onEventDetected : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('이벤트 클립 생성'),
                ),
                ElevatedButton(
                  onPressed: _lastClipPath != null ? _saveClipToGallery : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('갤러리에 저장'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            // 이벤트 작업 리스트
            if (jobs.isNotEmpty) ...[
              const Text(
                '이벤트 작업 목록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: jobs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final ts = DateTime.fromMillisecondsSinceEpoch(job.eventTimeMs);
                  final timeLabel = '${ts.hour.toString().padLeft(2,'0')}:'
                      '${ts.minute.toString().padLeft(2,'0')}:'
                      '${ts.second.toString().padLeft(2,'0')}';
                  return Card(
                    child: ListTile(
                      title: Text('이벤트 @ $timeLabel'),
                      subtitle: Text('${job.state.runtimeType}'.replaceAll('()', '')),
                      trailing: job.state is WaitingSegments
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            
            // 정보 업데이트 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateStorageStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Text('정보 업데이트'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
