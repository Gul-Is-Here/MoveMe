import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// A photo full screen, pinch-to-zoom.
void showPhotoFullScreen(ImageProvider image) {
  Get.dialog(
    Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: InteractiveViewer(maxScale: 5, child: Center(child: Image(image: image)))),
          const _CloseButton(),
        ],
      ),
    ),
  );
}

/// Plays a chat video full screen.
void showVideoFullScreen(String url) {
  Get.dialog(Dialog.fullscreen(backgroundColor: Colors.black, child: _VideoPlayerView(url: url)));
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: SafeArea(
        child: IconButton(
          tooltip: 'Close',
          onPressed: Get.back,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _VideoPlayerView extends StatefulWidget {
  const _VideoPlayerView({required this.url});

  final String url;

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  late final _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return Stack(
      children: [
        Center(
          child: _failed
              ? const Text("Couldn't play this video", style: TextStyle(color: Colors.white))
              : ready
                  ? GestureDetector(
                      onTap: () => setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      }),
                      child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
        ),
        if (ready)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: VideoProgressIndicator(_controller, allowScrubbing: true, padding: EdgeInsets.zero),
            ),
          ),
        const _CloseButton(),
      ],
    );
  }
}
