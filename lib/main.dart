import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:tflite_audio/tflite_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  bool isRunning = false;
  Duration duration = const Duration();
  late Ticker _ticker;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool isRecording = false;
  String audioFilePath = '';
  int secondsCounter = 0;
  bool activated = false;
  StreamSubscription<Map<dynamic, dynamic>>? recognitionStream;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (isRunning) {
        setState(() {
          duration += const Duration(seconds: 1);
        });
        secondsCounter += 1;
        if (secondsCounter >= 1800) {
          _restartRecording();
          secondsCounter = 0;
        }
      }
    });
    _initializeRecorder();
    _loadModel(); // Load the TFLite model
  }

  Future<void> _loadModel() async {
    // Load the TFLite model using tflite_audio
    try {
      await TfliteAudio.loadModel(
        model: 'assets/model.tflite', // Path to your model file
        label: 'assets/labels.txt',   // Path to your label file
        numThreads: 1,                // Number of threads to use for inference
        isAsset: true,                // True if the model and label files are in the assets directory
        inputType: 'rawAudio',        // Specify the input type as raw audio
      );
      print("TFLite model loaded successfully.");
    } catch (e) {
      print("Error loading TFLite model: $e");
    }
  }


  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.openAudioSession();
    Directory tempDir = await getTemporaryDirectory();
    audioFilePath = '${tempDir.path}/audio.aac';
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startTimer() {
    _ticker.start();
    setState(() {
      isRunning = true;
    });
  }

  void _stopTimer() {
    _ticker.stop();
    setState(() {
      isRunning = false;
    });
  }

  void _resetTimer() {
    setState(() {
      duration = const Duration();
      secondsCounter = 0;
    });
  }

  void _startRecording() {
    _recorder.startRecorder(toFile: audioFilePath);
    setState(() {
      isRecording = true;
    });
  }

  void _stopRecording() {
    _recorder.stopRecorder();
    setState(() {
      isRecording = false;
    });
  }

  void _restartRecording() async {
    _checkAudio(); // processes current recording
    _stopRecording();
    _startRecording();
  }

  void _activateFeature() {
    if (isRecording) {
      _stopRecording();
    }
    else {
      _startRecording();
    }

    activated = !activated;

    // Logic for activating the feature goes here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feature activated!')),
    );

  }


  void _checkAudio() async {
    try {
      // Start the audio recognition stream using tflite_audio
      recognitionStream = TfliteAudio.startAudioRecognition(
        sampleRate: 44100,          // Set sample rate to 44.1kHz as required by the model
        bufferSize: 44032,           // Buffer size set to match the model's input (1 second of audio)
        detectionThreshold: 0.5,     // You can adjust this based on confidence threshold
        averageWindowDuration: 1000, // 1-second window, matching the model's input size
        suppressionTime: 1500,       // Suppress repeated predictions for 1.5 seconds
        numOfInferences: 1,          // Process one inference at a time
        audioLength: 1000,           // Input audio length of 1 second
      ).listen((event) {
        String recognizedLabel = event['recognitionResult'];
        double confidence = double.tryParse(event['confidence']) ?? 0.0;

        print('Recognized: $recognizedLabel, Confidence: $confidence');

        // Check if the recognized label indicates music and the confidence is high enough
        if (recognizedLabel == 'Music' && confidence > 0.5) {
          _startTimer(); // Start the timer if music is detected
        } else {
          _stopTimer();  // Stop the timer if it's background noise
        }
      }, onError: (error) {
        print('Error in audio recognition: $error');
      });
    } catch (e) {
      print("Error during TFLite model inference: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[5000], // Lighter shade of black
        title: Row(
          children: const [
            Icon(Icons.music_note, color: Colors.white),
            SizedBox(width: 10),
            Text("Tune Tracker"),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Spacer(flex: 2),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250, // Increased size for larger circle
                  height: 250, // Increased size for larger circle
                  child: CircularProgressIndicator(
                    value: (duration.inSeconds % 3600) / 3600.0,
                    strokeWidth: 8,
                    color: Colors.blue,
                    backgroundColor: Colors.grey,
                  ),
                ),
                Text(
                  '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 48, color: Colors.white),
                ),
              ],
            ),
            const Spacer(flex: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isRunning ? _stopTimer : _startTimer,
                  child: Text(
                      isRunning ? 'Stop' : 'Start',
                      style: TextStyle(color: Colors.black)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Dark blue color
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _resetTimer,
                  child: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.black)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey, // Grey color for reset button
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _activateFeature,
                  child: Text(
                      isRecording ? 'Deactivate' : 'Activate',
                      style: TextStyle(color: Colors.black)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600], // Dark blue color
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
                  ),
                ),
              ],
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}