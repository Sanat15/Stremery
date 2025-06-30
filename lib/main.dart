import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:camera/camera.dart';
import 'secrets.dart'; // Contains: const geminiKey = "YOUR_API_KEY";
import 'message_model.dart';

void main() => runApp(StremeryTestApp());

class StremeryTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stremery Voice Debugger',
      theme: ThemeData.dark(),
      home: TranscriptionScreen(),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  @override
  _TranscriptionScreenState createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  final List<ChatMessage> _chatMessages = [];

  List<String> _fakeUsernames = [
    'AI_Bot_01',
    'HyperZebra',
    'NekoChan',
    'EchoVoid',
    'StreamGuru',
    'PixelTroll',
  ];
  String _transcribedText = 'Press the mic and speak';
  String _summaryText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeCamera(); // 👈 call camera init
  }

  Future<String> getGeminiSummary(String transcript) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$geminiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Summarize the following livestream transcript in one sentence:\n\n$transcript",
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded["candidates"][0]["content"]["parts"][0]["text"];
    } else {
      print("Gemini API Error: ${response.body}");
      return "Failed to get summary.";
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) async {
            setState(() {
              _transcribedText = result.recognizedWords;
            });
            if (result.finalResult) {
              final summary = await getGeminiSummary(result.recognizedWords);
              setState(() {
                _chatMessages.add(
                  ChatMessage(
                    username:
                        _fakeUsernames[_chatMessages.length %
                            _fakeUsernames.length],
                    message: summary,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCam = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(
      frontCam,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Voice to Text – Stremery")),
      body: Stack(
        children: [
          _isCameraInitialized
              ? CameraPreview(_cameraController!)
              : Center(child: CircularProgressIndicator()),

          Container(color: Colors.black.withOpacity(0.5)),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          _chatMessages[_chatMessages.length - 1 - index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(msg.username[0])),
                        title: Text(
                          msg.username,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(msg.message),
                        dense: true,
                      );
                    },
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _listen,
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                  label: Text(
                    _isListening ? "Stop Listening" : "Start Listening",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
