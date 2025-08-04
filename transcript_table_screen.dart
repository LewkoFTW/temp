import 'dart:typed_data';
import 'package:flutter/material.dart';

class TranscriptEntry {
  final String id;
  String name;
  final String text;
  final DateTime dateTime;
  final Duration duration;
  final Uint8List audioBytes;

  TranscriptEntry({
    required this.id,
    required this.name,
    required this.text,
    required this.dateTime,
    required this.duration,
    required this.audioBytes,
  });

  int get wordCount => text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  int get charCountWithSpaces => text.length;
  int get charCountWithoutSpaces => text.replaceAll(RegExp(r'\s+'), '').length;
}

class TranscriptTableScreen extends StatefulWidget {
  const TranscriptTableScreen({super.key});

  @override
  State<TranscriptTableScreen> createState() => _TranscriptTableScreenState();
}

class _TranscriptTableScreenState extends State<TranscriptTableScreen> {
  List<TranscriptEntry> _savedTranscripts = [];

  @override
  void initState() {
    super.initState();
    _loadMockData();
  }

  void _loadMockData() {
    setState(() {
      _savedTranscripts = [
        TranscriptEntry(
          id: '1',
          name: 'Recording1.wav',
          text: 'TEXT TEST 1.',
          dateTime: DateTime.now(),
          duration: Duration(seconds: 8),
          audioBytes: Uint8List(0),
        ),
        TranscriptEntry(
          id: '2',
          name: 'Interview1.wav',
          text: 'TEXT TEST 2.',
          dateTime: DateTime.now().subtract(Duration(days: 1)),
          duration: Duration(seconds: 15),
          audioBytes: Uint8List(0),
        ),
      ];
    });
  }

  String _formatDate(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  String _formatTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  void _playAudio(TranscriptEntry entry) {
    print("Play audio for: ${entry.name}");
  }

  void _downloadAudio(TranscriptEntry entry) {
    print("Download audio for: ${entry.name}");
  }

  void _downloadText(TranscriptEntry entry) {
    print("Download transcript text for: ${entry.name}");
  }

  void _deleteEntry(int index) {
    setState(() {
      _savedTranscripts.removeAt(index);
    });
  }

  Future<void> _editEntryName(int index) async {
    final newName = await _promptForName(_savedTranscripts[index].name);
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() {
        _savedTranscripts[index].name =
        newName.endsWith('.wav') ? newName : '$newName.wav';
      });
    }
  }

  Future<String?> _promptForName(String currentName) async {
    String temp = currentName;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Transcript Name"),
          content: TextField(
            controller: TextEditingController(text: currentName),
            onChanged: (val) => temp = val,
            decoration: const InputDecoration(hintText: "Enter new name"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, temp), child: const Text("Save")),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Transcript Table"),
      ),
      body: _savedTranscripts.isEmpty
          ? const Center(child: Text("No transcripts available."))
          : ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: _savedTranscripts.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final entry = _savedTranscripts[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Date: ${_formatDate(entry.dateTime)}  🕒 Time: ${_formatTime(entry.dateTime)}"),
                  const SizedBox(height: 4),
                  Text("Name: ${entry.name}"),
                  const SizedBox(height: 4),
                  Text("Duration: ${entry.duration.inSeconds} seconds"),
                  const SizedBox(height: 4),
                  Text("Words: ${entry.wordCount}"),
                  Text("Characters (with/without space): ${entry.charCountWithSpaces} / ${entry.charCountWithoutSpaces}"),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _playAudio(entry)),
                      IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadAudio(entry)),
                      IconButton(icon: const Icon(Icons.text_snippet), onPressed: () => _downloadText(entry)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteEntry(index)),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _editEntryName(index)),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
