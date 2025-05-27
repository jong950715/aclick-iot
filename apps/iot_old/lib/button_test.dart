import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iot/services/sound_manager.dart';
import 'package:iot/services/volume_key_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = '볼륨 업 키 대기 중';
  final VolumeKeyManager _volumeKeyManager = VolumeKeyManager();

  @override
  void initState() {
    super.initState();
    _volumeKeyManager.setOnVolumeUpCallback(
      () {
        print("onVolumeUp");
        SoundManager().playEvent();
        setState(() {
          _status = '📢 Volume Up 이벤트 발생';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Volume Key Demo')),
        body: Center(child: Text(_status, style: TextStyle(fontSize: 24))),
      ),
    );
  }
}
