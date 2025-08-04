import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:sonioxtest/transcript_table_screen.dart';

void main() {
  runApp(SonioxApp());
}

class SonioxApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soniox Transcription',
      home: TranscriptionHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TranscriptionHomePage extends StatefulWidget {
  @override
  _TranscriptionHomePageState createState() => _TranscriptionHomePageState();
}

class _TranscriptionHomePageState extends State<TranscriptionHomePage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ScrollController _scrollController = ScrollController();

  IOWebSocketChannel? _channel;
  Timer? _timer;
  String _transcript = '';
  String _interim = '';
  int _wordCount = 0;
  int _charWithSpaces = 0;
  int _charWithoutSpaces = 0;
  Duration _duration = Duration.zero;
  bool _recording = false;

  Future<void> requestMicPermissionAndStart() async {
    var status = await Permission.microphone.status;

    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      print("Microphone permission granted. Starting...");
      _startRecording();
    } else {
      print("Microphone permission denied.");
    }
  }

  final String _currentUser = "demo_user";

  @override
  void initState() {
    super.initState();
  }

  void _updateStats(String text) {
    setState(() {
      _wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      _charWithSpaces = text.length;
      _charWithoutSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    });
  }

  void _startTimer() {
    _duration = Duration.zero;
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _duration += Duration(seconds: 1);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  Future<void> _startRecording() async {
    await _recorder.openRecorder();
    await _recorder.startRecorder(codec: Codec.pcm16);

    _channel = IOWebSocketChannel.connect(
      "ws://192.168.137.1:3000", // Your server address
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      customClient: HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
    );

    _channel!.sink.add(jsonEncode({
      "action": "start_transcription",
      "user": _currentUser,
    }));

    _channel!.stream.listen((event) {
      final data = jsonDecode(event);
      final tokens = data['tokens'];

      if (tokens != null && tokens is List) {
        final text = tokens.map((t) => t['text']).join();
        setState(() {
          if (tokens.any((t) => t['text'] == '<end>')) {
            _transcript += "$text ";
            _interim = '';
            _updateStats(_transcript);
          } else {
            _interim = text;
          }
        });
      }
    });

    setState(() {
      _transcript = '';
      _interim = '';
      _recording = true;
    });

    _startTimer();
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _channel?.sink.add(jsonEncode({
      "action": "stop_transcription",
      "user": _currentUser,
    }));
    _channel?.sink.close();
    _stopTimer();

    setState(() {
      _recording = false;
    });
  }

  Future<String?> _promptForName() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Save Transcript As"),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: Text("Save")),
        ],
      ),
    );
  }

  void _clearTranscript() {
    setState(() {
      _transcript = '';
      _interim = '';
      _wordCount = 0;
      _charWithSpaces = 0;
      _charWithoutSpaces = 0;
    });
  }

  String _formatDuration(Duration d) => d.toString().split('.').first.padLeft(8, "0");

  @override
  void dispose() {
    _recorder.closeRecorder();
    _timer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffc3d3e0),
      appBar: AppBar(
        title: Text("Soniox Real-Time Transcription"),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.white,
              child: Text(
                "SONIOX TRANSCRIPTION",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(height: 20),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: _recording ? null : requestMicPermissionAndStart,
                icon: Icon(Icons.mic),
                label: Text("START"),
                style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(50)),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _recording ? _stopRecording : null,
                icon: Icon(Icons.stop),
                label: Text("STOP"),
                style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(50)),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _clearTranscript,
                icon: Icon(Icons.clear),
                label: Text("CLEAR"),
                style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(50)),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TranscriptTableScreen()),
                  );
                },
                icon: Icon(Icons.library_books),
                label: Text("TRANSCRIPTS"),
                style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(50)),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            height: 250,
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: _transcript, style: TextStyle(color: Colors.black)),
                    TextSpan(text: _interim, style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(
            "🕒 ${_formatDuration(_duration)} | Words: $_wordCount | Char: $_charWithSpaces | W/O Spaces: $_charWithoutSpaces",
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text("By: Leon Kotnik", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
