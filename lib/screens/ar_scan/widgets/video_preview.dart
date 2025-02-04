import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class VideoPreview extends StatelessWidget {
  final YoutubePlayerController controller;
  final GlobalKey repaintKey;

  const VideoPreview({
    super.key, 
    required this.controller,
    required this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          controller: controller,
          aspectRatio: 16 / 9,
          backgroundColor: Colors.black,
        ),
      ),
    );
  }
}