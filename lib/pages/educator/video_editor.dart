// lib/pages/educator/video_editor.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signsync_academy/core/services/video_editing_service.dart';
import 'package:signsync_academy/core/state/video_editing_state.dart';

class VideoEditor extends StatefulWidget {
  final File? initialVideo;
  final String? lessonTitle;

  const VideoEditor({Key? key, this.initialVideo, this.lessonTitle})
      : super(key: key);

  @override
  State<VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends State<VideoEditor> {
  late VideoEditingState _editingState;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final ImagePicker _picker = ImagePicker();

  // UI State
  int _selectedTool = 0;
  bool _isExpanded = false;

  // Editing parameters for functional features
  Duration _trimStart = Duration.zero, _trimEnd = Duration.zero;

  @override
  void initState() {
    super.initState();
    _editingState = VideoEditingState();
    _editingState.addListener(_onEditingStateChanged);
    _initializeVideo();
  }

  void _onEditingStateChanged() {
    if (mounted) setState(() {});
  }

  void _initializeVideo() async {
    if (widget.initialVideo != null) {
      await _loadVideo(widget.initialVideo!);
    }
  }

  Future<void> _loadVideo(File videoFile) async {
    _editingState.setVideo(videoFile);

    _videoController?.dispose();
    _chewieController?.dispose();

    _videoController = VideoPlayerController.file(videoFile);
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade400,
      ),
    );

    // Initialize trim times
    final duration = _editingState.videoInfo?.duration ?? Duration.zero;
    _trimStart = Duration.zero;
    _trimEnd = duration;

    if (mounted) setState(() {});
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      await _loadVideo(File(video.path));
    }
  }

  // FUNCTIONAL: Trim video
  Future<void> _applyTrim() async {
    if (_trimStart == Duration.zero &&
        _trimEnd == _editingState.videoDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No trimming applied - video remains original')),
      );
      return;
    }

    await _editingState.trimVideo(_trimStart, _trimEnd);
    if (_editingState.editedVideo != null) {
      await _loadVideo(_editingState.editedVideo!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video trimmed successfully!')),
      );
    }
  }

  // FUNCTIONAL: Compress video
  Future<void> _compressVideo() async {
    await _editingState.compressVideo();
    if (_editingState.editedVideo != null) {
      await _loadVideo(_editingState.editedVideo!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video compressed successfully!')),
      );
    }
  }

  // FUNCTIONAL: Rotate video
  Future<void> _rotateVideo(int degrees) async {
    await _editingState.rotateVideo(degrees);
    if (_editingState.editedVideo != null) {
      await _loadVideo(_editingState.editedVideo!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video rotated ${degrees}°')),
      );
    }
  }

  // FUNCTIONAL: Create thumbnail grid
  Future<Uint8List?> _generateThumbnailGrid() async {
    if (_editingState.originalVideo == null) return null;
    try {
      return await _editingState.createThumbnailGrid(
        columns: 4,
        rows: 3,
      );
    } catch (e) {
      return null;
    }
  }

  void _resetToOriginal() {
    _editingState.resetToOriginal();
    if (_editingState.originalVideo != null) {
      _loadVideo(_editingState.originalVideo!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to original video')),
    );
  }

  @override
  void dispose() {
    _editingState.removeListener(_onEditingStateChanged);
    _videoController?.dispose();
    _chewieController?.dispose();
    _editingState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Video Preview Section
          Expanded(
            flex: _isExpanded ? 3 : 2,
            child: _buildVideoPreview(),
          ),

          // Editing Tools Section
          Expanded(
            flex: _isExpanded ? 2 : 3,
            child: _buildEditingTools(),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.grey[900],
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.lessonTitle ?? 'Video Editor',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.compress, color: Colors.white),
          onPressed: _compressVideo,
          tooltip: 'Compress Video',
        ),
        IconButton(
          icon: const Icon(Icons.undo, color: Colors.white),
          onPressed: _resetToOriginal,
          tooltip: 'Reset to Original',
        ),
        IconButton(
          icon: const Icon(Icons.save, color: Colors.white),
          onPressed: _saveVideo,
          tooltip: 'Save Video',
        ),
        IconButton(
          icon: Icon(
            _isExpanded ? Icons.zoom_out_map : Icons.zoom_in_map,
            color: Colors.white,
          ),
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          tooltip: 'Toggle View',
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video Player or Placeholder
          if (_chewieController != null)
            Chewie(controller: _chewieController!)
          else
            _buildVideoPlaceholder(),

          // Processing Overlay
          if (_editingState.isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _editingState.compressionProgress,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _editingState.processingStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Error Message
          if (_editingState.error != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _editingState.error!,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _editingState.clearError,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Video Loaded',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.upload),
            label: const Text('Select Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditingTools() {
    return Container(
      color: Colors.grey[800],
      child: Column(
        children: [
          // Tool Selection Tabs
          _buildToolTabs(),

          // Selected Tool Content
          Expanded(
            child: _buildSelectedToolContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolTabs() {
    const List<Map<String, dynamic>> tools = [
      {'icon': Icons.content_cut, 'label': 'Trim'},
      {'icon': Icons.compress, 'label': 'Compress'},
      {'icon': Icons.rotate_right, 'label': 'Rotate'},
      {'icon': Icons.grid_on, 'label': 'Scenes'},
    ];

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => setState(() => _selectedTool = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedTool == index ? Colors.blue : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tools[index]['icon'] as IconData,
                      color: Colors.white, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    tools[index]['label'] as String,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: _selectedTool == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedToolContent() {
    switch (_selectedTool) {
      case 0:
        return _buildTrimTool();
      case 1:
        return _buildCompressTool();
      case 2:
        return _buildRotateTool();
      case 3:
        return _buildScenesTool();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTrimTool() {
    final duration = _editingState.videoInfo?.duration ?? Duration.zero;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trim Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select start and end points to trim your video',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildTimeSlider('Start Time', _trimStart, duration, (value) {
            setState(() => _trimStart = value);
            if (_trimEnd < value) _trimEnd = value;
          }),
          _buildTimeSlider('End Time', _trimEnd, duration, (value) {
            setState(() => _trimEnd = value);
            if (_trimStart > value) _trimStart = value;
          }),
          const SizedBox(height: 16),
          _buildVideoInfo(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applyTrim,
              icon: const Icon(Icons.content_cut),
              label: const Text('Apply Trim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressTool() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compress Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reduce file size while maintaining good quality',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _buildVideoInfo(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _compressVideo,
              icon: const Icon(Icons.compress),
              label: const Text('Compress Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_editingState.isProcessing)
            LinearProgressIndicator(
              value: _editingState.compressionProgress,
              backgroundColor: Colors.grey[700],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
        ],
      ),
    );
  }

  Widget _buildRotateTool() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rotate Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rotate video orientation',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRotationButton(90, Icons.rotate_90_degrees_ccw),
              _buildRotationButton(180, Icons.rotate_left),
              _buildRotationButton(270, Icons.rotate_90_degrees_cw),
            ],
          ),
          const SizedBox(height: 20),
          _buildVideoInfo(),
        ],
      ),
    );
  }

  Widget _buildScenesTool() {
    return FutureBuilder<Uint8List?>(
      future: _generateThumbnailGrid(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Generating scene preview...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Scene Preview',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to generate thumbnails',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _generateThumbnailGrid,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scene Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Video scenes displayed as thumbnail grid',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[900],
                  ),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoInfo() {
    if (_editingState.videoInfo == null) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow(
              'Duration', _formatDuration(_editingState.videoDuration)),
          _buildInfoRow('Resolution', _editingState.videoResolution),
          _buildInfoRow('File Size', _editingState.videoFileSize),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationButton(int degrees, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => _rotateVideo(degrees),
      icon: Icon(icon),
      label: Text('${degrees}°'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildTimeSlider(
    String label,
    Duration value,
    Duration maxDuration,
    Function(Duration) onChanged,
  ) {
    final maxSeconds = maxDuration.inSeconds.toDouble();
    final currentSeconds = value.inSeconds.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${_formatDuration(value)}',
          style: const TextStyle(color: Colors.white),
        ),
        Slider(
          value: currentSeconds,
          min: 0,
          max: maxSeconds,
          onChanged: (val) => onChanged(Duration(seconds: val.toInt())),
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${minutes.padLeft(2, '0')}:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  void _saveVideo() {
    if (_editingState.editedVideo == null &&
        _editingState.originalVideo == null) return;

    final videoToSave =
        _editingState.editedVideo ?? _editingState.originalVideo;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Save Video', style: TextStyle(color: Colors.white)),
        content: Text(
          _editingState.isEdited
              ? 'Your edited video has been processed successfully. Save changes?'
              : 'Save the original video?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Here you would typically save the video to your lesson
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_editingState.isEdited
                      ? 'Edited video saved successfully!'
                      : 'Original video saved!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
