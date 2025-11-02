import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerService {
  static VideoPlayerController? _videoPlayerController;
  static ChewieController? _chewieController;

  static Future<void> playVideo(
      BuildContext context, String videoUrl, String title) async {
    if (videoUrl.isEmpty) {
      _showSnackBar(context, 'No video available for this lesson', Colors.red);
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading video...'),
            ],
          ),
        ),
      );

      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey.shade300,
          bufferedColor: Colors.grey.shade500,
        ),
        placeholder: Container(
          color: Colors.grey.shade900,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        autoInitialize: true,
      );

      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _buildVideoPlayerScreen(title),
            fullscreenDialog: true,
          ),
        );

        _disposeVideoPlayer();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(
            context, 'Error playing video: ${e.toString()}', Colors.red);
      }
    }
  }

  static Widget _buildVideoPlayerScreen(String title) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _disposeVideoPlayer();
            Navigator.pop(navigatorKey.currentContext!);
          },
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _chewieController != null &&
                  _chewieController!.videoPlayerController.value.isInitialized
              ? Chewie(controller: _chewieController!)
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading video...',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }

  static void _disposeVideoPlayer() {
    _chewieController?.pause();
    _chewieController?.dispose();
    _videoPlayerController?.pause();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  static void _showSnackBar(
      BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<void> downloadVideo(
      BuildContext context, String videoUrl, String title) async {
    // Simple download implementation
    _showSnackBar(context, 'Download feature coming soon!', Colors.blue);
  }

  // Global navigator key for accessing context
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
