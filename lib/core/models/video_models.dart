// lib/core/models/video_models.dart
import 'dart:io';
import 'package:flutter/material.dart';

// Use a different name to avoid conflict with video_compress
enum CompressionQuality {
  low,
  medium,
  high,
}

class VideoInfo {
  final Duration duration;
  final Size resolution;
  final double frameRate;
  final int fileSize;
  final String path;

  VideoInfo({
    required this.duration,
    required this.resolution,
    required this.frameRate,
    required this.fileSize,
    required this.path,
  });
}

class VideoSegment {
  final Duration start;
  final Duration end;
  final String? thumbnailPath;

  VideoSegment({
    required this.start,
    required this.end,
    this.thumbnailPath,
  });
}

class VideoFilter {
  final String name;
  final String type;
  final Map<String, dynamic> parameters;

  VideoFilter({
    required this.name,
    required this.type,
    required this.parameters,
  });
}

class CompressionSettings {
  final CompressionQuality quality;
  final int bitrate;
  final double scaleFactor;

  const CompressionSettings({
    required this.quality,
    required this.bitrate,
    required this.scaleFactor,
  });

  static const CompressionSettings low = CompressionSettings(
    quality: CompressionQuality.low,
    bitrate: 1000000,
    scaleFactor: 0.5,
  );

  static const CompressionSettings medium = CompressionSettings(
    quality: CompressionQuality.medium,
    bitrate: 2500000,
    scaleFactor: 0.75,
  );

  static const CompressionSettings high = CompressionSettings(
    quality: CompressionQuality.high,
    bitrate: 5000000,
    scaleFactor: 1.0,
  );

  // Convert to video_compress quality
  int get videoCompressQuality {
    switch (quality) {
      case CompressionQuality.low:
        return 30;
      case CompressionQuality.medium:
        return 50;
      case CompressionQuality.high:
        return 75;
      default:
        return 50;
    }
  }
}
