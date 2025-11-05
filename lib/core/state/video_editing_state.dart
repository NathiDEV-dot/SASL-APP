// lib/core/state/video_editing_state.dart
// ignore_for_file: annotate_overrides, must_call_super

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signsync_academy/core/services/video_editing_service.dart';
import 'package:signsync_academy/core/models/video_models.dart';

class VideoEditingState with ChangeNotifier {
  File? _originalVideo;
  File? _editedVideo;
  VideoInfo? _videoInfo;
  bool _isProcessing = false;
  String? _error;
  double _compressionProgress = 0.0;

  final VideoEditingService _editingService = VideoEditingService();

  File? get originalVideo => _originalVideo;
  File? get editedVideo => _editedVideo;
  VideoInfo? get videoInfo => _videoInfo;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  double get compressionProgress => _compressionProgress;

  VideoEditingState() {
    _editingService.initialize();
  }

  void dispose() {
    _editingService.dispose();
  }

  void setVideo(File videoFile) async {
    _originalVideo = videoFile;
    _editedVideo = videoFile;
    _error = null;
    _compressionProgress = 0.0;

    try {
      _videoInfo = await _editingService.getVideoInfo(videoFile);
    } catch (e) {
      _error = 'Failed to load video info: $e';
    }

    notifyListeners();
  }

  Future<void> trimVideo(Duration startTime, Duration endTime) async {
    if (_originalVideo == null) return;

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      _editedVideo = await _editingService.trimVideo(
        inputVideo: _originalVideo!,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _error = 'Trimming failed: $e';
    }

    _isProcessing = false;
    notifyListeners();
  }

  Future<void> compressVideo() async {
    if (_originalVideo == null) return;

    _isProcessing = true;
    _error = null;
    _compressionProgress = 0.0;
    notifyListeners();

    try {
      // Simulate progress for better UX
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        _compressionProgress = i / 10;
        notifyListeners();
      }

      _editedVideo = await _editingService.compressVideo(_originalVideo!);
    } catch (e) {
      _error = 'Compression failed: $e';
    }

    _isProcessing = false;
    _compressionProgress = 1.0;
    notifyListeners();
  }

  Future<void> rotateVideo(int degrees) async {
    if (_originalVideo == null) return;

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      _editedVideo = await _editingService.rotateVideo(
        inputVideo: _originalVideo!,
        degrees: degrees,
      );
    } catch (e) {
      _error = 'Rotation failed: $e';
    }

    _isProcessing = false;
    notifyListeners();
  }

  Future<Uint8List> createThumbnailGrid({
    int columns = 4,
    int rows = 3,
  }) async {
    if (_originalVideo == null) {
      throw Exception('No video loaded');
    }

    try {
      return await _editingService.createThumbnailGrid(
        videoFile: _originalVideo!,
        columns: columns,
        rows: rows,
      );
    } catch (e) {
      throw Exception('Thumbnail grid creation failed: $e');
    }
  }

  void resetToOriginal() {
    _editedVideo = _originalVideo;
    _error = null;
    _compressionProgress = 0.0;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper methods for UI
  bool get hasVideo => _originalVideo != null;
  Duration get videoDuration => _videoInfo?.duration ?? Duration.zero;

  String get videoResolution {
    if (_videoInfo == null) return 'Unknown';
    return '${_videoInfo!.resolution.width.toInt()}x${_videoInfo!.resolution.height.toInt()}';
  }

  String get videoFileSize {
    if (_videoInfo == null) return 'Unknown';
    final sizeInMB = _videoInfo!.fileSize / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(2)} MB';
  }

  bool get isEdited => _editedVideo != null && _editedVideo != _originalVideo;

  String get processingStatus {
    if (!_isProcessing) return 'Ready';
    if (_compressionProgress > 0) {
      return 'Processing... ${(_compressionProgress * 100).toStringAsFixed(1)}%';
    }
    return 'Processing...';
  }
}
