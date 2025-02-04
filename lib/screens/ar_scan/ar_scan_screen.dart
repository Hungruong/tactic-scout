import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:http/http.dart' as http;
import 'widgets/video_preview.dart';
import 'widgets/scan_overlay.dart';
import 'widgets/player_card.dart';
import 'widgets/bottom_controls.dart';

class ARScanScreen extends StatefulWidget {
  const ARScanScreen({super.key});

  @override
  State<ARScanScreen> createState() => _ARScanScreenState();
}

class _ARScanScreenState extends State<ARScanScreen> {
  late YoutubePlayerController _controller;
  final GlobalKey _repaintKey = GlobalKey();
  bool _isScanning = false;
  bool _isPlayerFound = false;
  Map<String, dynamic>? _playerInfo;

  static const String _videoId = 'T4d7DE0_I5s';

  @override
  void initState() {
    super.initState();
    initializeYouTubePlayer();
  }

  Future<void> initializeYouTubePlayer() async {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: _videoId,
      params: const YoutubePlayerParams(
        mute: true,
        showControls: false,
        showFullscreenButton: false,
        loop: true,
        strictRelatedVideos: true,
      ),
    );
    await _controller.loadVideo(_videoId);
  }

  Future<Uint8List?> _captureFrame() async {
    try {
      // Get the RenderRepaintBoundary
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Convert to image
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing frame: $e');
      return null;
    }
  }

  Future<void> _processScan() async {
    setState(() {
      _isScanning = true;
      _isPlayerFound = false; // Reset trước khi scan mới
      _playerInfo = null;
    });

    try {
      await _controller.pauseVideo();

      final bytes = await _captureFrame();
      if (bytes == null) {
        _showError('Failed to capture frame');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8001/detect'),
      );
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'frame.jpg'));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['players']?.isNotEmpty == true) {
          // Lấy số áo đầu tiên tìm thấy
          String detectedNumber = data['players'].keys.first;
          var playerData = data['players'][detectedNumber];

          if (playerData != null) {
            setState(() {
              _playerInfo = {
                "name": playerData['info']['person']['fullName'] ?? "Unknown Player",
                "number": detectedNumber,
                "team": playerData['info']['team'] ?? "Unknown Team",
                "position": playerData['info']['position']['name'] ?? "Unknown Position",
                "stats": playerData['stats'] ?? {},
              };
              _isPlayerFound = true;
            });
          }
        } else {
          _showError('No player detected. Please try again.');
        }
      } else {
        _showError('Failed to process image. Status: ${response.statusCode}');
        print('Server response: ${response.body}');
      }

      await _controller.playVideo();

    } catch (e) {
      _showError('Error during scan: $e');
      print('Error details: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetScan() {
    setState(() {
      _isScanning = false;
      _isPlayerFound = false;
      _playerInfo = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: VideoPreview(
              controller: _controller,
              repaintKey: _repaintKey,
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                if (_isScanning && !_isPlayerFound) 
                  const ScanOverlay(),
                if (_isPlayerFound && _playerInfo != null)
                  PlayerCard(
                    playerInfo: _playerInfo!,
                    onClose: _resetScan,
                  ),
                const Spacer(),
                BottomControls(
                  onScanPressed: _isScanning ? null : _processScan,
                  onResetPressed: _resetScan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'AR Scanner',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}