import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  bool _isRecording = false;
  bool _isInitialized = false;

  // Get available cameras
  Future<List<CameraDescription>> getAvailableCameras() async {
    return await availableCameras();
  }

  // Initialize camera
  Future<void> initializeCamera(CameraDescription camera) async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw Exception('Camera permission denied');
    }

    // Request microphone permission for video recording
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Microphone permission denied');
    }

    // Dispose previous controller
    await _controller?.dispose();

    // Create new controller
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    // Initialize controller
    await _controller!.initialize();
    _isInitialized = true;
  }

  // Start recording
  Future<File> startRecording() async {
    if (_controller == null || !_isInitialized) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) {
      throw Exception('Already recording');
    }

    try {
      _isRecording = true;
      await _controller!.startVideoRecording();

      // Return a future that completes when recording is stopped
      return await _waitForRecordingStop();
    } catch (e) {
      _isRecording = false;
      throw Exception('Failed to start recording: $e');
    }
  }

  // Stop recording
  Future<void> stopRecording() async {
    if (_controller == null || !_isRecording) {
      return;
    }

    try {
      _isRecording = false;
      await _controller!.stopVideoRecording();
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  // Wait for recording to complete and return the file
  Future<File> _waitForRecordingStop() async {
    while (_isRecording) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Return the recorded file
    final file = File(_controller!.description.name);
    return file;
  }

  // Get camera controller for preview
  CameraController? get controller => _controller;

  // Check if recording
  bool get isRecording => _isRecording;

  // Check if initialized
  bool get isInitialized => _isInitialized;

  // Dispose resources
  Future<void> dispose() async {
    await _controller?.dispose();
    _isInitialized = false;
    _isRecording = false;
  }
}
