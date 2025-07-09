import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myrailway/home_page.dart'; // Your existing HomePage
import 'firebase_options.dart';
import 'login_page.dart'; // Your existing LoginPage
import 'package:video_player/video_player.dart'; // Required for video playback
import 'package:chewie/chewie.dart'; // Required for video playback

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      // Set the AppInitializer as the initial home widget.
      // This widget will handle video playback and then navigate.
      home: const AppInitializer(),
    );
  }
}

// New widget to handle the video playback and initial navigation logic
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasNavigated = false; // Flag to ensure navigation happens only once

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // Initialize the video player with your asset video
    _videoPlayerController = VideoPlayerController.asset('assets/railscore_vid.mp4');
    await _videoPlayerController.initialize();

    // Configure Chewie controller for video playback
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true, // Video starts playing automatically
      looping: false, // Video plays only once
      showControls: false, // No playback controls visible
      aspectRatio: _videoPlayerController.value.aspectRatio,
      placeholder: Container(
        color: Colors.blueGrey, // A background color while video loads
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white), // Loading indicator
        ),
      ),
    );

    // --- IMPORTANT: This listener detects when the video has finished playing ---
    _videoPlayerController.addListener(() {
      if (_videoPlayerController.value.position == _videoPlayerController.value.duration && !_hasNavigated) {
        // Video finished playing and we haven't navigated yet, now navigate to the next screen
        _navigateToNextScreen();
      }
    });

    setState(() {}); // Rebuild the widget to display the video player
  }

  // --- This method contains the logic for navigating to the respective page ---
  void _navigateToNextScreen() {
    // Ensure navigation happens only once and after the widget is still mounted
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true; // Set flag to true to prevent future navigations

    User? user = FirebaseAuth.instance.currentUser; // Synchronously get current user

    if (user == null) {
      // If 'user' is null, it means no user is logged in.
      // Navigate to the LoginPage.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      // If 'user' is not null, it means a user is logged in.
      // Navigate to the HomePage.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  void dispose() {
    // Dispose of the video player and Chewie controller to free up resources
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Background color for the splash screen
      body: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
          ? SizedBox.expand( // Make the video fill the entire screen
              child: FittedBox(
                fit: BoxFit.cover, // Cover the screen while maintaining aspect ratio
                child: SizedBox(
                  width: _videoPlayerController.value.size.width,
                  height: _videoPlayerController.value.size.height,
                  child: Chewie(
                    controller: _chewieController!,
                  ),
                ),
              ),
            )
          : Container(
              color: Colors.blueGrey, // Background color while video is initializing
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
    );
  }
}
