import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:player_final/splash_screen.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Demo',
      theme: ThemeData.light(), // Set the default light theme
      darkTheme: ThemeData.dark(), // Set the default dark theme
      home: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Demo',
      home: SplashScreen(),
    );
  }
}

class VideoScreen extends StatefulWidget {
  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? _controller;

  Timer? _hideTimer;
  bool showPlayButton = true;
  bool showQualityOptions = false;
  bool showSlider = true;
  double currentPosition = 0.0;
  bool isFullScreen = false;
  bool showFullScreenButton = true;
  List<String> m3u8Urls = [];
  int currentVideoIndex = 0;
  bool isDarkMode = false;
  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    fetchM3U8Urls(
        'https://arynews.aryzap.com/fca6168787200f5a74998d6f30f9e8ad/64a48234/v1/0183ea205add0b8ed5941a38bc6f/0183ea20909b0b8ed5aa4d793456/main.m3u8')
        .then((urls) {
      m3u8Urls = urls;
      if (m3u8Urls.isNotEmpty) {
        _initializeAndPlay(m3u8Urls);
      }
    }).catchError((error) {
      print('Error fetching M3U8 URLs: $error');
    });
  }

  void _initializeAndPlay(List<String> urls) {
    if (_controller != null) {
      _controller!.dispose();
    }

    _controller = VideoPlayerController.network(urls.first)
      ..initialize().then((_) {
        setState(() {
          _controller!.play();
          _controller!.addListener(_videoListener);
        });
      }).catchError((error) {
        print('Error initializing video player: $error');
      });
  }

  void _videoListener() {
    if (_controller != null &&
        !_controller!.value.isPlaying &&
        _controller!.value.duration == _controller!.value.position) {
      _goToNextVideo();
    }
    setState(() {
      currentPosition = _controller?.value.position.inMilliseconds.toDouble() ??
          0.0;
    });
  }

  void _goToNextVideo() {
    if (currentVideoIndex + 1 < m3u8Urls.length) {
      currentVideoIndex++;
      _initializeAndPlay([m3u8Urls[currentVideoIndex]]);
    } else {
      print('End of playlist');
    }
  }

  Future<List<String>> fetchM3U8Urls(String webpageUrl) async {
    final response = await http.get(Uri.parse(webpageUrl));

    if (response.statusCode == 200) {
      final playlist = response.body;
      final segmentUrls = parseM3U8Playlist(playlist, webpageUrl);

      return segmentUrls;
    } else {
      throw Exception('Failed to load webpage');
    }
  }

  List<String> parseM3U8Playlist(String playlist, String baseUrl) {
    final lines = LineSplitter.split(playlist);
    final segmentUrls = <String>[];

    for (final line in lines) {
      if (line.trim().isNotEmpty && !line.startsWith('#')) {
        segmentUrls
            .add(Uri.parse(baseUrl).resolve(line.trim()).toString());
      }
    }

    return segmentUrls;
  }

  void _togglePlay() {
    setState(() {
      if (_controller != null && _controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      showPlayButton = !(_controller != null && _controller!.value.isPlaying);
      showSlider = !(_controller != null && _controller!.value.isPlaying);
      _startHideTimer();
    });
  }

  void _startHideTimer() {
    if (_hideTimer != null && _hideTimer!.isActive) {
      _hideTimer!.cancel();
    }

    _hideTimer = Timer(Duration(seconds: 3), () {
      setState(() {
        showPlayButton = false;
        showQualityOptions = false;
        showSlider = false;
        showFullScreenButton = false;
      });
    });
  }

  void _onScreenTap() {
    setState(() {
      if (showPlayButton) {
        showPlayButton = false;
        showQualityOptions = false;
        showSlider = false;
        showFullScreenButton = false;
        _cancelHideTimer();
      } else {
        showPlayButton = true;
        showQualityOptions = true;
        showSlider = true;
        showFullScreenButton = true;
        _startHideTimer();
      }
    });
  }

  void _cancelHideTimer() {
    if (_hideTimer != null && _hideTimer!.isActive) {
      _hideTimer!.cancel();
    }

    if (!isFullScreen) {
      _hideTimer = Timer(Duration(seconds: 3), () {
        setState(() {
          showPlayButton = false;
          showQualityOptions = false;
          showSlider = false;
          showFullScreenButton = false;
        });
      });
    }
  }

  void _selectQualityOption(String option) {
    // Handle the selected quality option
    print('Selected quality option: $option');
  }

  void _onSliderChanged(double value) {
    if (_controller != null && _controller!.value.isInitialized) {
      final position = Duration(
          milliseconds:
          (value * _controller!.value.duration.inMilliseconds).round());
      _controller!.seekTo(position);
    }
  }

  void _toggleFullScreenMode() {
    setState(() {
      if (isFullScreen) {
        // Switch back to portrait mode
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,

        ]);
      } else {
        // Switch to landscape mode
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      isFullScreen = !isFullScreen;
      _startHideTimer();
    });
  }

  void _toggleMute() {
    setState(() {
      isMuted = !isMuted;
      _controller?.setVolume(isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkMode ? ThemeData.dark() : ThemeData.light();

    // Set the screen orientation based on the full-screen mode
    if (isFullScreen) {
      SystemChrome.setEnabledSystemUIOverlays([]);
    } else {
      SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    }

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: isFullScreen ? null : AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF007AFF), // Start color
                  Color(0xFF000080),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          centerTitle: true,
          title: Text('LivePulse'),
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nights_stay),
              onPressed: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
            ),
          ],
        ),
        body: GestureDetector(
          onTap: _onScreenTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: _controller != null &&
                    _controller!.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: Stack(
                    children: [
                      VideoPlayer(_controller!),
                      if (showSlider)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Opacity(
                            opacity: showSlider ? 1.0 : 0.0,
                            child: Slider(
                              activeColor: Colors.red,
                              value: currentPosition /
                                  _controller!.value.duration.inMicroseconds,
                              min: -10,
                              max: 100.0,
                              onChanged: _onSliderChanged,
                            ),
                          ),
                        ),
                      if (showFullScreenButton)
                        Positioned(
                          top: 20.0,
                          right: 20.0,
                          child: GestureDetector(
                            onTap: _toggleFullScreenMode,
                            child: Icon(
                              isFullScreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white.withOpacity(0.7),
                              size: 30.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
                    : CircularProgressIndicator(),
              ),
              if (_controller != null && showPlayButton)
                GestureDetector(
                  onTap: _togglePlay,
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.grey.withOpacity(0.7),
                    size: 80.0,
                  ),
                ),
              Positioned(
                  bottom: 20.0,
                  left: 20.0,
                  child: IconButton(
                    icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
                    color: isMuted ? Colors.red : Colors.grey.withOpacity(1),
                    onPressed: _toggleMute,
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelHideTimer();
    if (_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }
}